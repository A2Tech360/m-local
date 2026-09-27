"""Behavioral checks for public place acquisition, independent of live OSM."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.simulation import places


def node(identity=1, **updates):
    result = {"type": "node", "id": identity, "lat": 42.28, "lon": -83.75,
              "tags": {"name": "Test cafe", "amenity": "cafe"}}
    result.update(updates)
    return result


class NormalizeTests(unittest.TestCase):
    def test_element_type_is_part_of_identity_and_unknown_hours_stay_unknown(self):
        result, report = places.normalize_elements({"elements": [
            node(), node(type="way", lat=None, lon=None,
                         center={"lat": 42.281, "lon": -83.751})]})
        self.assertEqual([p["id"] for p in result], ["osm:node:1", "osm:way:1"])
        self.assertIsNone(result[0]["opening_hours"])
        self.assertEqual(result[1]["coordinate_method"], "osm_bounding_box_center")
        self.assertEqual(report["retained_count"], 2)

    def test_invalid_coordinates_unnamed_and_closed_places_are_excluded(self):
        elements = [node(), node(2, lat=float("nan")), node(3, lon=200),
                    node(4, lat=True), node(5, tags={"amenity": "cafe"}),
                    node(6, tags={"name": "Old cafe", "amenity": "cafe", "disused": "yes"}),
                    node(7, tags={"name": "Closed cafe", "amenity": "cafe", "opening_hours": "closed"})]
        result, report = places.normalize_elements({"elements": elements})
        self.assertEqual([p["id"] for p in result], ["osm:node:1"])
        self.assertEqual(report["excluded_counts"], {"invalid_coordinates": 3, "unnamed": 1, "closed_or_disused": 2})

    def test_same_name_nearby_is_flagged_without_merging_distant_branches(self):
        result, report = places.normalize_elements({"elements": [
            node(), node(2, lat=42.2801), node(3, lat=42.32)]})
        self.assertEqual(len(result), 3)
        self.assertEqual(len(report["possible_duplicates"]), 1)
        self.assertEqual(report["possible_duplicates"][0]["place_ids"], ["osm:node:1", "osm:node:2"])
        self.assertIn("possible_duplicate", result[0]["quality_flags"])
        self.assertNotIn("possible_duplicate", result[2]["quality_flags"])

    def test_multiple_categories_and_source_fields_survive(self):
        result, _ = places.normalize_elements({"elements": [node(tags={
            "name": "  Cafe Books  ", "amenity": "cafe", "shop": "books",
            "addr:housenumber": "123", "addr:street": "Main Street",
            "opening_hours": "Mo-Fr 09:00-17:00", "website": "https://example.test"})]})
        self.assertEqual(result[0]["name"], "Cafe Books")
        self.assertEqual(result[0]["categories"], ["cafe", "bookshop"])
        self.assertEqual(result[0]["source_url"], "https://www.openstreetmap.org/node/1")
        self.assertEqual(result[0]["address"]["street"], "Main Street")

    def test_historical_name_and_cuisine_do_not_close_an_active_business(self):
        result, report = places.normalize_elements({"elements": [node(tags={
            "name": "Current restaurant", "amenity": "restaurant",
            "was:name": "Old restaurant", "was:cuisine": "ice_cream"})]})
        self.assertEqual(len(result), 1)
        self.assertEqual(report["excluded_counts"], {})

    def test_output_order_does_not_depend_on_upstream_order(self):
        inputs = [node(4), node(2), node(3)]
        first, _ = places.normalize_elements({"elements": inputs})
        second, _ = places.normalize_elements({"elements": list(reversed(inputs))})
        self.assertEqual(first, second)

    def test_incomplete_payload_is_rejected_even_when_some_elements_exist(self):
        for payload in ({"elements": [node()], "remark": "runtime error: timeout"},
                        {"error": "upstream failed"}, {"elements": "incorrect"}):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                places.normalize_elements(payload)

    def test_boundary_members_distinguish_city_from_surrounding_buffer(self):
        boundary = {"type": "relation", "id": 135130, "tags": {"type": "boundary"},
                    "members": [{"type": "way", "role": "outer", "geometry": [
                        {"lat": 42.27, "lon": -83.76}, {"lat": 42.27, "lon": -83.74},
                        {"lat": 42.29, "lon": -83.74}, {"lat": 42.29, "lon": -83.76},
                        {"lat": 42.27, "lon": -83.76}]}]}
        result, _ = places.normalize_elements({"elements": [node(), node(2, lat=42.30), boundary]})
        self.assertEqual([p["scope"] for p in result], ["city", "boundary_buffer"])


class SnapshotTests(unittest.TestCase):
    def test_failed_refresh_preserves_previous_snapshot(self):
        for failure in (OSError("network unavailable"), ValueError("invalid JSON")):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as folder:
                output = Path(folder)
                (output / "places.json").write_text("last good data", encoding="utf-8")
                with patch.object(places, "_request", side_effect=failure):
                    with self.assertRaises((OSError, ValueError)):
                        places.fetch_snapshot(output)
                self.assertEqual((output / "places.json").read_text(), "last good data")

    def test_small_incomplete_refresh_does_not_replace_good_data(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            (output / "places.json").write_text("last good data", encoding="utf-8")
            with patch.object(places, "_request", return_value=json.dumps({"elements": [node()]}).encode()):
                with self.assertRaises(ValueError):
                    places.fetch_snapshot(output)
            self.assertEqual((output / "places.json").read_text(), "last good data")

    def test_valid_snapshot_retains_raw_bytes_hashes_and_offline_geometry(self):
        raw = json.dumps({"elements": [node(i, tags={"name": f"Cafe {i}", "amenity": "cafe"})
                                        for i in range(1, 201)]}).encode()
        geometry = json.dumps({"elements": [{"type": "way", "id": 8,
            "tags": {"highway": "residential"}, "geometry": [
                {"lat": 42.28, "lon": -83.75}, {"lat": 42.281, "lon": -83.751}]}]}).encode()
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            with patch.object(places, "_request", side_effect=[raw, geometry]):
                manifest = places.fetch_snapshot(output)
            self.assertEqual(manifest["place_count"], 200)
            self.assertEqual(len(json.loads((output / "places.json").read_text())), 200)
            self.assertEqual((output / manifest["files"]["raw"]["path"]).read_bytes(), raw)
            self.assertEqual(len(manifest["files"]["raw"]["sha256"]), 64)
            map_data = json.loads((output / "source" / "map_geometry.json").read_text())
            self.assertEqual(map_data["roads"], [[[-83.75, 42.28], [-83.751, 42.281]]])
            self.assertIn("OpenStreetMap", (output / "attribution.txt").read_text())

    def test_offline_rebuild_keeps_original_source_timestamp_and_bytes(self):
        raw = json.dumps({"elements": [node(i, tags={"name": f"Cafe {i}", "amenity": "cafe"})
                                        for i in range(1, 201)]}).encode()
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            with patch.object(places, "_request", side_effect=[raw, b'{"elements": []}']):
                original = places.fetch_snapshot(output)
            with patch.object(places, "_request", side_effect=AssertionError("offline rebuild requested network")):
                rebuilt = places.fetch_snapshot(output, reuse_source=output / "source" / "manifest.json")
            self.assertEqual(rebuilt["retrieved_at"], original["retrieved_at"])
            self.assertEqual(rebuilt["snapshot_id"], original["snapshot_id"])
            self.assertEqual(rebuilt["files"]["raw"]["sha256"], original["files"]["raw"]["sha256"])


if __name__ == "__main__":
    unittest.main()
