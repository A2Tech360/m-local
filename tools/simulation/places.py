"""Acquire a public OSM snapshot for the isolated M-Local simulation.

Uses only the Python standard library. This catalog creates neither accounts nor
offers. A place's source presence does not establish current operation/access.
"""

from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import io
import json
import math
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ENDPOINT = "https://overpass-api.de/api/interpreter"
BOUNDARY_ID = 135130
BUFFER_METERS = 1500
MINIMUM_PLACES = 200
LICENSE_URL = "https://www.openstreetmap.org/copyright"
ATTRIBUTION = (
    "Place and map data © OpenStreetMap contributors.\n"
    "Open Database License (ODbL) 1.0: https://opendatacommons.org/licenses/odbl/1-0/\n"
    "Attribution and copyright: https://www.openstreetmap.org/copyright\n"
    "Source: https://overpass-api.de/api/interpreter\n"
    "Public source records are not verified merchant participation.\n"
    "Offers, customers, and activity shown by the simulation are synthetic.\n"
)
TAG_CATEGORIES = {
    "amenity": {
        "restaurant": "restaurant", "cafe": "cafe", "fast_food": "fast_food",
        "ice_cream": "dessert", "bar": "bar", "pub": "bar",
        "library": "library", "cinema": "entertainment", "theatre": "entertainment",
        "arts_centre": "gallery",
    },
    "shop": {
        "bakery": "bakery", "books": "bookshop", "ice_cream": "dessert",
        "confectionery": "dessert", "chocolate": "dessert", "pastry": "dessert",
        "gift": "retail", "florist": "retail", "clothes": "retail",
        "antiques": "retail", "second_hand": "retail", "music": "retail",
        "art": "gallery", "games": "retail", "toys": "retail", "sports": "retail",
    },
    "leisure": {"park": "park", "garden": "park", "bowling_alley": "entertainment"},
    "tourism": {"museum": "museum", "gallery": "gallery", "attraction": "entertainment"},
}


def _poi_query() -> str:
    # Around a set of boundary ways measures distance to their line segments.
    # Including the area also retains points far inside the city boundary.
    queries = []
    for key, values in TAG_CATEGORIES.items():
        regex = "^(" + "|".join(values) + ")$"
        for spatial in ("area.city_area", f"around.boundary:{BUFFER_METERS}"):
            queries.append(f'  nwr({spatial})["{key}"~"{regex}"];')
    return (
        "[out:json][timeout:90][maxsize:67108864];\n"
        f"rel({BOUNDARY_ID})->.city;\n"
        ".city map_to_area->.city_area;\n"
        "way(r.city)->.boundary;\n(\n" + "\n".join(queries)
        + "\n);\nout center;\n.city out geom;\n"
    )


def _geometry_query(bounds: list[float]) -> str:
    bbox = ",".join(f"{number:.6f}" for number in bounds)
    return (
        "[out:json][timeout:90][maxsize:67108864];\n(\n"
        f'  way({bbox})["highway"~"^(primary|secondary|tertiary|residential|pedestrian|unclassified)$"];\n'
        f'  way({bbox})["waterway"="river"];\n'
        f'  way({bbox})["natural"="water"];\n'
        ");\nout geom;\n"
    )


def _request(query: str) -> bytes:
    """At most two sequential attempts; never retry an invalid data response."""
    request = urllib.request.Request(
        ENDPOINT, data=urllib.parse.urlencode({"data": query}).encode("utf-8"),
        headers={"User-Agent": "M-Local-JacHacks-demo/1.0 (local public-data snapshot)",
                 "Content-Type": "application/x-www-form-urlencoded"},
    )
    for attempt in range(2):
        try:
            with urllib.request.urlopen(request, timeout=110) as response:
                result = response.read(40_000_001)
                if len(result) > 40_000_000:
                    raise ValueError("Overpass response exceeds 40 MB snapshot limit")
                return result
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            if attempt or (isinstance(error, urllib.error.HTTPError)
                           and error.code not in (429, 500, 502, 503, 504)):
                raise
            time.sleep(15)
    raise RuntimeError("unreachable")


def _validate_payload(payload: dict) -> list[dict]:
    if not isinstance(payload, dict) or payload.get("remark") or payload.get("error"):
        raise ValueError("Overpass returned an error or incomplete snapshot")
    elements = payload.get("elements")
    if not isinstance(elements, list) or not all(isinstance(e, dict) for e in elements):
        raise ValueError("Overpass snapshot must contain an elements array")
    return elements


def _valid_coordinate(lat: Any, lon: Any) -> bool:
    return all(isinstance(n, (float, int)) and not isinstance(n, bool)
               and math.isfinite(n) for n in (lat, lon)) and -90 <= lat <= 90 and -180 <= lon <= 180


def _boundary_rings(elements: list[dict]) -> tuple[list[list[tuple[float, float]]], int]:
    relations = [e for e in elements if e.get("type") == "relation" and e.get("id") == BOUNDARY_ID]
    if not relations:
        return [], 0
    segments = []
    for member in relations[0].get("members", []):
        if member.get("type") != "way" or member.get("role") not in ("outer", "inner", ""):
            continue
        points = [(p["lon"], p["lat"]) for p in member.get("geometry", [])
                  if _valid_coordinate(p.get("lat"), p.get("lon"))]
        if len(points) >= 2:
            segments.append(points)
    rings = []
    incomplete = 0
    while segments:
        ring = segments.pop()
        while ring[-1] != ring[0]:
            found = False
            for index, segment in enumerate(segments):
                if segment[0] == ring[-1]:
                    ring.extend(segment[1:])
                elif segment[-1] == ring[-1]:
                    ring.extend(list(reversed(segment))[1:])
                else:
                    continue
                segments.pop(index)
                found = True
                break
            if not found:
                break
        if ring[0] == ring[-1] and len(ring) >= 4:
            rings.append(ring)
        else:
            incomplete += 1
    return rings, incomplete


def _point_in_city(lon: float, lat: float, rings: list[list[tuple[float, float]]]) -> bool:
    # Even/odd parity respects holes and disconnected city polygons.
    inside = False
    for ring in rings:
        for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
            if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
                inside = not inside
    return inside


def _distance_meters(first: dict, second: dict) -> float:
    dlat = math.radians(second["lat"] - first["lat"])
    dlon = math.radians(second["lon"] - first["lon"])
    a = (math.sin(dlat / 2) ** 2 + math.cos(math.radians(first["lat"]))
         * math.cos(math.radians(second["lat"])) * math.sin(dlon / 2) ** 2)
    return 6_371_000 * 2 * math.asin(min(1.0, math.sqrt(a)))


def _closed(tags: dict) -> bool:
    for key in ("disused", "abandoned", "demolished", "closed"):
        if str(tags.get(key, "")).lower() in ("yes", "true", "1"):
            return True
        if any(key + ":" + feature in tags for feature in TAG_CATEGORIES):
            return True
    return str(tags.get("opening_hours", "")).strip().lower() in ("closed", "off")


def normalize_elements(payload: dict) -> tuple[list[dict], dict]:
    """Normalize real source records without inventing hours, access, or ownership."""
    elements = _validate_payload(payload)
    rings, incomplete_rings = _boundary_rings(elements)
    excluded: collections.Counter = collections.Counter()
    rejected = []
    records: dict[str, dict] = {}
    for element in elements:
        if element.get("type") == "relation" and element.get("id") == BOUNDARY_ID:
            continue
        tags = element.get("tags", {})
        if not isinstance(tags, dict):
            tags = {}
        categories = list(dict.fromkeys(mapping[tags[key]] for key, mapping in TAG_CATEGORIES.items()
                                       if tags.get(key) in mapping))
        source_type, source_id = element.get("type"), element.get("id")
        identity = f"osm:{source_type}:{source_id}"
        reason = None
        if source_type not in ("node", "way", "relation") or not isinstance(source_id, int):
            reason = "invalid_identity"
        elif _closed(tags):
            reason = "closed_or_disused"
        elif not categories:
            reason = "unsupported_category"
        elif not isinstance(tags.get("name"), str) or not tags["name"].strip():
            reason = "unnamed"
        center = element if source_type == "node" else element.get("center", {})
        if not isinstance(center, dict):
            center = {}
        lat, lon = center.get("lat"), center.get("lon")
        if reason is None and not _valid_coordinate(lat, lon):
            reason = "invalid_coordinates"
        if reason:
            excluded[reason] += 1
            rejected.append({"source_id": identity, "reason": reason})
            continue
        flags = []
        if source_type != "node":
            flags.append("approximate_center_not_entrance")
        if not tags.get("opening_hours"):
            flags.append("hours_unknown")
        if tags.get("access") in ("private", "no", "customers"):
            flags.append("restricted_access_tag")
        scope = ("city" if _point_in_city(lon, lat, rings) else "boundary_buffer") if rings and not incomplete_rings else "city_or_boundary_buffer_unclassified"
        address = {key: tags.get("addr:" + key) or None for key in
                   ("housenumber", "street", "unit", "city", "state", "postcode", "country")}
        records[identity] = {
            "id": identity, "place_id": identity, "name": tags["name"].strip(),
            "category": categories[0], "categories": categories,
            "lat": lat, "lon": lon, "latitude": lat, "longitude": lon,
            "type": source_type, "source_type": source_type, "source_id": source_id,
            "source": "OpenStreetMap", "source_url": f"https://www.openstreetmap.org/{source_type}/{source_id}",
            "coordinate_method": "osm_node" if source_type == "node" else "osm_bounding_box_center",
            "address": address, "cuisine": tags.get("cuisine") or None,
            "website": tags.get("website") or tags.get("contact:website") or None,
            "opening_hours": tags.get("opening_hours") or None,
            "source_status_tags": {k: v for k, v in tags.items() if k in ("access", "check_date", "check_date:opening_hours", "operator", "brand")},
            "scope": scope, "area_scope": scope, "review_status": "unreviewed_public_source",
            "quality_flags": flags, "license": "ODbL-1.0", "license_url": LICENSE_URL,
            "retrieved_at": None, "source_snapshot_id": None,
        }
    places = sorted(records.values(), key=lambda place: place["id"])
    duplicates = []
    by_name: dict[str, list[dict]] = collections.defaultdict(list)
    for place in places:
        normalized_name = " ".join(place["name"].casefold().split())
        for other in by_name[normalized_name]:
            distance = _distance_meters(place, other)
            if distance <= 50:
                duplicates.append({"place_ids": sorted([place["id"], other["id"]]),
                                   "distance_meters": round(distance, 1), "reason": "same_name_within_50_meters"})
                for candidate in (place, other):
                    if "possible_duplicate" not in candidate["quality_flags"]:
                        candidate["quality_flags"].append("possible_duplicate")
        by_name[normalized_name].append(place)
    quality = {
        "raw_element_count": len(elements), "retained_count": len(places),
        "excluded_counts": dict(sorted(excluded.items())), "excluded_records": rejected,
        "category_counts": dict(sorted(collections.Counter(p["category"] for p in places).items())),
        "scope_counts": dict(sorted(collections.Counter(p["scope"] for p in places).items())),
        "missing_fields": {key: sum(not p[key] for p in places) for key in ("website", "opening_hours", "cuisine")},
        "missing_street_address": sum(not p["address"]["street"] for p in places),
        "possible_duplicates": duplicates, "automatically_merged": 0,
        "boundary_closed_rings": len(rings), "boundary_incomplete_rings": incomplete_rings,
        "limitations": [
            "Selected OSM categories are not a complete business census or freshness audit.",
            "Merchant ownership, participation, public access and current opening status are unverified.",
            "City scope is based on point or bounding-box center containment; centers are not entrances.",
            "The 1500 m source buffer measures distance to city boundary lines, including township holes.",
            "Straight-line distances are not pedestrian routes or walking times.",
            "Nearby same-name candidates remain distinct until manually reviewed.",
        ],
    }
    return places, quality


def _map_geometry(payload: dict) -> dict:
    roads, water = [], []
    for element in _validate_payload(payload):
        points = [[p["lon"], p["lat"]] for p in element.get("geometry", [])
                  if _valid_coordinate(p.get("lat"), p.get("lon"))]
        if len(points) < 2:
            continue
        tags = element.get("tags", {})
        if tags.get("highway"):
            roads.append(points)
        if tags.get("waterway") == "river" or tags.get("natural") == "water":
            water.append(points)
    return {"roads": roads, "water": water}


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def _publish(path: Path, data: bytes) -> None:
    temporary = path.with_name(path.name + ".tmp-" + uuid.uuid4().hex)
    temporary.write_bytes(data)
    os.replace(temporary, path)


def fetch_snapshot(output_dir: Path, *, reuse_source: Path | None = None) -> dict:
    """Stage and validate both downloads before replacing the last good catalog.

    Each completed snapshot is retained under source/<snapshot-id>. The source
    manifest is the commit marker; aliases provide convenient human inspection.
    Network, malformed data, and insufficient-coverage failures leave old files
    untouched. Missing records on a refresh are listed for review, never closed.
    """
    output_dir = Path(output_dir)
    reused = None
    def read_retained(key: str) -> bytes:
        entry = reused["files"][key]
        base = next(parent.parent for parent in reuse_source.resolve().parents if parent.name == "source")
        file = (base / entry["path"]).resolve()
        if not file.is_relative_to(base):
            raise ValueError("Retained snapshot path must remain inside its data directory")
        data = file.read_bytes()
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError("Retained source checksum mismatch")
        return data

    if reuse_source is not None:
        reuse_source = Path(reuse_source)
        reused = json.loads(reuse_source.read_text(encoding="utf-8"))
        query, raw = read_retained("query").decode("utf-8"), read_retained("raw")
    else:
        query = _poi_query()
        raw = _request(query)
    payload = json.loads(raw)
    places, quality = normalize_elements(payload)
    if len(places) < MINIMUM_PLACES:
        raise ValueError(f"Only {len(places)} usable records; minimum is {MINIMUM_PLACES}; retaining previous snapshot")
    retrieved_at = reused["retrieved_at"] if reused else datetime.now(timezone.utc).isoformat(timespec="seconds")
    snapshot_id = "osm-" + hashlib.sha256(raw).hexdigest()[:16]
    for place in places:
        place["retrieved_at"] = retrieved_at
        place["source_snapshot_id"] = snapshot_id
    bounds = [min(p["lat"] for p in places) - .001, min(p["lon"] for p in places) - .001,
              max(p["lat"] for p in places) + .001, max(p["lon"] for p in places) + .001]
    if reused:
        geometry_query = read_retained("geometry_query").decode("utf-8")
        geometry_raw = read_retained("geometry_raw")
        bounds = reused["scope"]["map_bbox_south_west_north_east"]
    else:
        geometry_query = _geometry_query(bounds)
        geometry_raw = _request(geometry_query)
    map_geometry = _map_geometry(json.loads(geometry_raw))
    map_geometry.update({"bounds": bounds, "source": "OpenStreetMap", "license_url": LICENSE_URL,
                         "snapshot_id": snapshot_id})
    previous = output_dir / "places.json"
    missing = []
    if previous.exists():
        old_places = json.loads(previous.read_text(encoding="utf-8"))
        current_ids = {p["id"] for p in places}
        missing = sorted(p["id"] for p in old_places if p["id"] not in current_ids)
    quality.update({"retrieved_at": retrieved_at, "source_snapshot_id": snapshot_id,
                    "missing_since_previous_snapshot_requires_review": missing})
    csv_stream = io.StringIO(newline="")
    writer = csv.DictWriter(csv_stream, fieldnames=["id", "name", "category", "lat", "lon", "scope", "opening_hours", "website", "source_url"])
    writer.writeheader()
    for place in places:
        writer.writerow({key: place[key] for key in writer.fieldnames})
    contents = {
        "raw": ("overpass.json", raw), "query": ("query.overpassql", query.encode()),
        "geometry_raw": ("map-overpass.json", geometry_raw),
        "geometry_query": ("map-query.overpassql", geometry_query.encode()),
        "places": ("places.json", _json_bytes(places)),
        "jsonl": ("places.jsonl", b"".join((json.dumps(p, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8") for p in places)),
        "csv": ("places.csv", csv_stream.getvalue().encode("utf-8")),
        "quality": ("place-quality.json", _json_bytes(quality)),
        "map_geometry": ("map_geometry.json", _json_bytes(map_geometry)),
        "attribution": ("attribution.txt", ATTRIBUTION.encode("utf-8")),
    }
    source_dir = output_dir / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    # Timestamp avoids overwriting provenance if the service returns identical raw bytes.
    directory_name = snapshot_id + "-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:6]
    staged = source_dir / (".staging-" + uuid.uuid4().hex)
    staged.mkdir()
    files = {}
    for key, (name, data) in contents.items():
        (staged / name).write_bytes(data)
        files[key] = {"path": f"source/{directory_name}/{name}", "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
    manifest = {
        "schema_version": 1, "snapshot_id": snapshot_id, "retrieved_at": retrieved_at,
        "normalized_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "endpoint": ENDPOINT, "osm_base_timestamp": payload.get("osm3s", {}).get("timestamp_osm_base"),
        "place_count": len(places), "source": "OpenStreetMap", "license": "ODbL-1.0", "license_url": LICENSE_URL,
        "scope": {"method": "city_area_union_1500m_around_boundary_ways", "boundary_relation": BOUNDARY_ID,
                  "buffer_meters": BUFFER_METERS, "point_membership": "even_odd_boundary_rings_using_node_or_center",
                  "map_bbox_south_west_north_east": bounds},
        "files": files,
    }
    (staged / "manifest.json").write_bytes(_json_bytes(manifest))
    os.replace(staged, source_dir / directory_name)
    _publish(output_dir / "places.json", contents["places"][1])
    _publish(output_dir / "place-quality.json", contents["quality"][1])
    _publish(output_dir / "attribution.txt", contents["attribution"][1])
    _publish(source_dir / "map_geometry.json", contents["map_geometry"][1])
    _publish(source_dir / "manifest.json", _json_bytes(manifest))
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[2] / "data" / "simulation")
    parser.add_argument("--reuse-source", type=Path, help="Offline renormalization from a retained source/manifest.json; checks source hashes")
    arguments = parser.parse_args()
    manifest = fetch_snapshot(arguments.output_dir, reuse_source=arguments.reuse_source)
    print(json.dumps({"snapshot_id": manifest["snapshot_id"], "place_count": manifest["place_count"],
                      "manifest": str(arguments.output_dir / "source" / "manifest.json")}, indent=2))


if __name__ == "__main__":
    main()
