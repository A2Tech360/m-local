"""Validation and geometry boundaries used by the real application catalog."""

import copy
import math
import unittest

from services.place_support import (
    distance_m,
    normalize_place_batch,
    validate_nearby_request,
    validate_page,
)


def record(identity=1, **changes):
    value = {
        "id": f"osm:node:{identity}", "name": "Fixture cafe", "category": "cafe",
        "lat": 42.28, "lon": -83.75, "source_type": "node", "source_id": identity,
        "source_url": f"https://www.openstreetmap.org/node/{identity}",
        "coordinate_method": "osm_node", "address": {"street": "Main Street", "unit": None},
        "website": None, "opening_hours": None, "retrieved_at": "2026-09-27T03:49:41+00:00",
    }
    value.update(changes)
    return value


class CatalogValidationTests(unittest.TestCase):
    def test_preserves_unknown_metadata_and_stable_source_identity(self):
        source = record()
        untouched = copy.deepcopy(source)
        result = normalize_place_batch([source])[0]
        self.assertEqual(result["id"], "osm:node:1")
        self.assertEqual(result["source_id"], "1")
        self.assertIsNone(result["website"])
        self.assertIsNone(result["opening_hours"])
        self.assertIsNone(result["address"]["unit"])
        self.assertEqual(source, untouched)

    def test_rejects_identity_mismatch_and_invalid_coordinates(self):
        for changes in ({"lat": math.nan}, {"lat": True}, {"lon": 181},
                        {"id": "osm:way:1"}, {"source_url": "https://example.com/node/1"},
                        {"name": " "}, {"retrieved_at": "yesterday"}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                normalize_place_batch([record(**changes)])

    def test_rejects_duplicate_and_authority_fields_before_returning(self):
        with self.assertRaises(ValueError):
            normalize_place_batch([record(), record()])
        for key in ("owner_actor_id", "merchant_key", "offers", "price", "roles", "password"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                normalize_place_batch([record(), record(2, **{key: "untrusted"})])

    def test_distance_is_symmetric_and_about_111_metres_per_millidegree(self):
        expected = distance_m(42.28, -83.75, 42.281, -83.75)
        self.assertAlmostEqual(expected, 111.195, places=2)
        self.assertEqual(expected, distance_m(42.281, -83.75, 42.28, -83.75))
        self.assertEqual(distance_m(42.28, -83.75, 42.28, -83.75), 0)

    def test_query_bounds_and_finiteness(self):
        validate_nearby_request("osm:node:1", 1200.0, 5, "park")
        for radius in (0, -1, 2001, math.inf, math.nan, True):
            with self.subTest(radius=radius), self.assertRaises(ValueError):
                validate_nearby_request("osm:node:1", radius, 5, "")
        for limit in (0, 21, True, 1.2):
            with self.subTest(limit=limit), self.assertRaises(ValueError):
                validate_nearby_request("osm:node:1", 1200.0, limit, "")
        validate_page(100, 0)
        for limit, offset in ((0, 0), (501, 0), (1, -1), (True, 0), (10, 1.1)):
            with self.subTest(limit=limit, offset=offset), self.assertRaises(ValueError):
                validate_page(limit, offset)

    def test_query_accepts_runtime_integer_subclasses_without_accepting_booleans(self):
        class RuntimeInt(int):
            pass
        validate_page(RuntimeInt(500), RuntimeInt(0))
        validate_nearby_request("osm:node:1", 1200.0, RuntimeInt(5), "park")
        with self.assertRaises(ValueError):
            validate_page(10, False)


if __name__ == "__main__":
    unittest.main()
