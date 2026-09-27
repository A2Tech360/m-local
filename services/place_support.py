"""Pure validation and geodesic helpers for the trusted OSM catalog importer.

This module never calls the network, changes the graph, or grants merchant roles.
Null source metadata stays unknown. Distances are point-to-point great-circle
distances, not pedestrian routes, travel times, or accessibility guarantees.
"""

from __future__ import annotations

import math
import re
from datetime import datetime
from typing import Any


_OSM_ID = re.compile(r"osm:(node|way|relation):([1-9][0-9]*)\Z")
_FORBIDDEN = {
    "merchant_key", "owner_actor_id", "password", "role", "roles", "offers",
    "price", "price_cents", "regular_price", "regular_price_cents",
}


def _text(value: Any, field: str, *, nullable: bool = False) -> str | None:
    if nullable and value is None:
        return None
    if not isinstance(value, str) or not value.strip() or len(value) > 4096:
        raise ValueError(f"place {field} must be non-empty text of at most 4096 characters")
    return value.strip()


def _coordinate(value: Any, bound: int, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"place {field} must be a finite coordinate")
    if not math.isfinite(value) or not -bound <= value <= bound:
        raise ValueError(f"place {field} is outside the coordinate range")
    return float(value)


def normalize_place_batch(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Validate the whole batch before a caller performs any graph mutations."""
    if not isinstance(records, list) or len(records) > 20000:
        raise ValueError("places must be a list with at most 20000 records")
    result: list[dict[str, Any]] = []
    identities: set[str] = set()
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("each place must be an object")
        forbidden = sorted(_FORBIDDEN.intersection(record))
        if forbidden:
            raise ValueError(f"place import cannot assign {forbidden[0]}")
        identity = _text(record.get("id"), "id")
        match = _OSM_ID.fullmatch(identity or "")
        if not match:
            raise ValueError("place id must be osm:node|way|relation:positive_id")
        source_type, source_id = match.groups()
        if record.get("source_type") != source_type or str(record.get("source_id")) != source_id:
            raise ValueError("place source identity disagrees with id")
        source_url = f"https://www.openstreetmap.org/{source_type}/{source_id}"
        if record.get("source_url") != source_url:
            raise ValueError("place source_url must identify the same OpenStreetMap record")
        if identity in identities:
            raise ValueError("place batch contains a duplicate source id")
        identities.add(identity)
        retrieved_at = _text(record.get("retrieved_at"), "retrieved_at")
        try:
            if datetime.fromisoformat(retrieved_at.replace("Z", "+00:00")).tzinfo is None:
                raise ValueError("missing timezone")
        except (TypeError, ValueError) as error:
            raise ValueError("place retrieved_at must be an ISO timestamp with timezone") from error
        address = record.get("address") or {}
        if not isinstance(address, dict) or len(address) > 20:
            raise ValueError("place address must be an object")
        clean_address = {}
        for key, value in address.items():
            clean_address[_text(key, "address key")] = _text(value, "address value", nullable=True)
        category = _text(record.get("category"), "category")
        categories = record.get("categories", [category])
        if not isinstance(categories, list) or not categories or len(categories) > 20:
            raise ValueError("place categories must be a non-empty list")
        categories = [_text(value, "category") for value in categories]
        if category not in categories:
            raise ValueError("place primary category must be in categories")
        coordinate_method = _text(record.get("coordinate_method"), "coordinate_method")
        expected_method = "osm_node" if source_type == "node" else "osm_bounding_box_center"
        if coordinate_method != expected_method:
            raise ValueError("place coordinate method disagrees with source type")
        quality_flags = record.get("quality_flags", [])
        if not isinstance(quality_flags, list) or len(quality_flags) > 40:
            raise ValueError("place quality_flags must be a list")
        quality_flags = [_text(value, "quality flag") for value in quality_flags]
        result.append({
            "id": identity, "name": _text(record.get("name"), "name"),
            "category": category, "categories": categories,
            "lat": _coordinate(record.get("lat"), 90, "lat"),
            "lon": _coordinate(record.get("lon"), 180, "lon"),
            "source_id": source_id, "source_type": source_type, "source_url": source_url,
            "address": clean_address, "coordinate_method": coordinate_method,
            "website": _text(record.get("website"), "website", nullable=True),
            "opening_hours": _text(record.get("opening_hours"), "opening_hours", nullable=True),
            "retrieved_at": retrieved_at,
            "quality_flags": quality_flags,
        })
    return result


def distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine distance on a mean-radius Earth; never a walking-route length."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi, dlon = phi2 - phi1, math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlon / 2) ** 2
    return 6371008.8 * 2 * math.atan2(math.sqrt(min(1, a)), math.sqrt(max(0, 1 - a)))


def validate_nearby_request(place_id: str, radius_m: float, limit: int, preference: str) -> None:
    if not isinstance(place_id, str) or not _OSM_ID.fullmatch(place_id):
        raise ValueError("place_id must be a stable OpenStreetMap place id")
    if (isinstance(radius_m, bool) or not isinstance(radius_m, (int, float))
            or not math.isfinite(radius_m) or not 0 < radius_m <= 2000):
        raise ValueError("radius_m must be finite and between 0 exclusive and 2000 inclusive")
    if isinstance(limit, bool) or not isinstance(limit, int) or not 1 <= limit <= 20:
        raise ValueError("limit must be an integer between 1 and 20")
    if not isinstance(preference, str) or len(preference) > 80:
        raise ValueError("preference must be a category string of at most 80 characters")


def validate_page(limit: int, offset: int) -> None:
    if isinstance(limit, bool) or not isinstance(limit, int) or not 1 <= limit <= 500:
        raise ValueError("limit must be an integer between 1 and 500")
    if isinstance(offset, bool) or not isinstance(offset, int) or offset < 0:
        raise ValueError("offset must be a nonnegative integer")
