"""Reusable source-backed places graph. Trusted imports, public read-only DTOs.

The catalog does not create merchants, accounts, prices, offers or business
participation. Nearby edges mean straight-line proximity only, not walkability.
Call import_places from a trusted local import command, never a public endpoint.
"""

import from services.models { Location }
import from services.place_support {
    normalize_place_batch, distance_m, validate_nearby_request, validate_page
}


node Place {
    def __jac_access__ -> AccessLevel { return AccessLevel.READ; }
    has place_id: str,
        name: str,
        category: str,
        lat: float,
        lon: float,
        source_id: str,
        source_type: str,
        source_url: str,
        coordinate_method: str,
        retrieved_at: str,
        categories: list[str] = [],
        quality_flags: list[str] = [],
        address: dict[str, str | None] = {},
        website: str | None = None,
        opening_hours: str | None = None;
}


edge Nearby: Place --> Place {
    def __jac_access__ -> AccessLevel { return AccessLevel.READ; }
    has distance_m: float,
        distance_kind: str = "straight_line",
        derived_by: str = "haversine-v1";
}


edge LocatedAt: Location --> Place {
    def __jac_access__ -> AccessLevel { return AccessLevel.READ; }
    has association: str = "explicit_reviewed_link";
}


obj PlaceView {
    has id: str,
        name: str,
        category: str,
        lat: float,
        lon: float,
        source_url: str,
        source_id: str,
        source_type: str,
        coordinate_method: str,
        retrieved_at: str,
        categories: list[str] = [],
        quality_flags: list[str] = [],
        address: dict[str, str | None] = {},
        website: str | None = None,
        opening_hours: str | None = None,
        attribution: str = "OpenStreetMap contributors",
        license: str = "ODbL-1.0";
}


obj NearbyPlaceView {
    has id: str,
        name: str,
        category: str,
        lat: float,
        lon: float,
        source_url: str,
        distance_m: float,
        reason: str,
        distance_kind: str = "straight_line";
}


def _place_view(p: Place) -> PlaceView {
    return PlaceView(
        id=p.place_id, name=p.name, category=p.category, lat=p.lat, lon=p.lon,
        source_url=p.source_url, source_id=p.source_id, source_type=p.source_type,
        coordinate_method=p.coordinate_method, retrieved_at=p.retrieved_at,
        categories=p.categories, quality_flags=p.quality_flags, address=p.address, website=p.website,
        opening_hours=p.opening_hours
    );
}


def _find_place(requested_id: str) -> Place {
    matches = [p for p in [root.shared -->[?:Place]] if p.place_id == requested_id];
    if len(matches) != 1 { raise ValueError("place_id must identify exactly one catalog place"); }
    return matches[0];
}


def _rebuild_nearby(places: list[Place]) {
    # Bound materialized degree to eight. Queries can still examine all places
    # for a custom radius, so edge sparsity cannot hide a matching destination.
    for origin in places {
        del [edge origin ->:Nearby:->];
        candidates: list[tuple[float, str, Place]] = [];
        for candidate in places {
            if candidate.place_id == origin.place_id or "restricted_access_tag" in candidate.quality_flags { continue; }
            distance = distance_m(origin.lat, origin.lon, candidate.lat, candidate.lon);
            if distance <= 1200.0 { candidates.append((distance, candidate.place_id, candidate)); }
        }
        candidates.sort(key=lambda (row: tuple[float, str, Place]) -> tuple[float, str] { return (row[0], row[1]); });
        for row in candidates[:8] {
            origin +>:Nearby(distance_m=row[0]):+> row[2];
        }
    }
}


"""Validate all records, then upsert by stable source id and derive proximity.

Returns the number of records processed (including refreshes). Missing records
are retained; an incomplete snapshot must not delete the last known catalog.
No input-validation failure mutates the graph. Run under trusted system root.
"""
def import_places(records: list[dict[str, any]]) -> int {
    validated = normalize_place_batch(records);
    catalog = [root.shared -->[?:Place]];
    indexed: dict[str, Place] = {};
    for existing in catalog {
        if existing.place_id in indexed { raise ValueError("duplicate place identity in existing catalog"); }
        indexed[existing.place_id] = existing;
    }
    for rec in validated {
        identity = rec["id"] as str;
        p: Place;
        if identity in indexed {
            p = indexed[identity];
        } else {
            p = Place(
                place_id=identity, name=rec["name"] as str, category=rec["category"] as str,
                lat=rec["lat"] as float, lon=rec["lon"] as float,
                source_id=rec["source_id"] as str, source_type=rec["source_type"] as str,
                source_url=rec["source_url"] as str, coordinate_method=rec["coordinate_method"] as str,
                retrieved_at=rec["retrieved_at"] as str
            );
            root.shared ++> p;
            indexed[identity] = p;
        }
        p.name = rec["name"] as str;
        p.category = rec["category"] as str;
        p.lat = rec["lat"] as float;
        p.lon = rec["lon"] as float;
        p.source_id = rec["source_id"] as str;
        p.source_type = rec["source_type"] as str;
        p.source_url = rec["source_url"] as str;
        p.coordinate_method = rec["coordinate_method"] as str;
        p.retrieved_at = rec["retrieved_at"] as str;
        p.categories = rec["categories"] as list[str];
        p.quality_flags = rec["quality_flags"] as list[str];
        p.address = rec["address"] as dict[str, str | None];
        p.website = rec["website"] as str | None;
        p.opening_hours = rec["opening_hours"] as str | None;
    }
    if validated { _rebuild_nearby(list(indexed.values())); }
    return len(validated);
}


"""Trusted reviewed association only; never call based on fuzzy/name matching."""
def link_location(location: Location, place_id: str) {
    p = _find_place(place_id);
    linked = [location ->:LocatedAt:->];
    if linked {
        if len(linked) != 1 or linked[0].place_id != place_id {
            raise ValueError("location already has a different reviewed place association");
        }
        return;
    }
    location +>:LocatedAt():+> p;
}


def:pub list_places(limit: int = 100, offset: int = 0) -> list[PlaceView] {
    validate_page(limit, offset);
    places = [root.shared -->[?:Place]];
    places.sort(key=lambda (p: Place) -> str { return p.place_id; });
    return [_place_view(p) for p in places[offset:offset + limit]];
}


"""Deterministic complementary suggestions using straight-line point distance.

The default radius is a candidate screen for a 10-15 minute walk, not evidence
that a pedestrian route exists. Unknown hours are never treated as open-now.
"""
def:pub nearby_places(place_id: str, radius_m: float = 1200.0, limit: int = 5, preference: str = "") -> list[NearbyPlaceView] {
    validate_nearby_request(place_id, radius_m, limit, preference);
    origin = _find_place(place_id);
    preference = preference.strip().lower();
    ranked: list[tuple[int, float, str, Place]] = [];
    for p in [root.shared -->[?:Place]] {
        if p.place_id == origin.place_id or "restricted_access_tag" in p.quality_flags { continue; }
        distance = distance_m(origin.lat, origin.lon, p.lat, p.lon);
        if distance > radius_m { continue; }
        rank = 0 if preference and preference in p.categories else 1;
        if not preference and p.category in ["cafe", "ice_cream", "bakery", "bookshop", "park", "museum", "gallery"] {
            rank = 0;
        }
        ranked.append((rank, distance, p.place_id, p));
    }
    ranked.sort(key=lambda (row: tuple[int, float, str, Place]) -> tuple[int, float, str] { return (row[0], row[1], row[2]); });
    result: list[NearbyPlaceView] = [];
    for row in ranked[:limit] {
        p = row[3];
        reason = "Nearby " + p.category.replace("_", " ") + "; straight-line distance, walking route unverified.";
        if preference and row[0] == 0 {
            reason = "Matches " + preference.replace("_", " ") + "; straight-line distance, walking route unverified.";
        }
        result.append(NearbyPlaceView(
            id=p.place_id, name=p.name, category=p.category, lat=p.lat, lon=p.lon,
            source_url=p.source_url, distance_m=row[1], reason=reason
        ));
    }
    return result;
}
