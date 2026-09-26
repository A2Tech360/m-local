"""Data import boundary.

Every restaurant enters the graph through f"import_restaurant(record)". The demo
seed uses it today; a future community-source adapter (CSV, partner feed) only
has to produce the same record shape. Offer times in a record are given as
hour offsets from import time so demo data is always fresh.
"""

import time;
import math;
import from services.models {
    Restaurant,
    Location,
    MenuItem,
    Offer,
    HasLocation,
    Serves,
    Publishes,
    Features
}
import from services.context_models {
    ContextNotice,
    Affects,
    ContextValidationError
}


def _reject_untrusted_identity_fields(record: dict) -> None {
    for key in ["merchant_key", "owner_actor_id", "password", "role", "roles"] {
        if key in record {
            raise ContextValidationError("import records cannot assign " + key);
        }
    }
}


def _notice_location(location_slug: str) -> Location {
    restaurants = [root-->[?:Restaurant, slug == location_slug]];
    if len(restaurants) != 1 {
        raise ContextValidationError("location_slug must resolve to exactly one restaurant");
    }
    locations = [restaurants[0] ->:HasLocation:->];
    if len(locations) != 1 {
        raise ContextValidationError("location_slug must resolve to exactly one location");
    }
    return locations[0];
}


def _validate_access_notice(record: dict) -> None {
    required = ["source_id", "external_id", "location_slug", "version", "publisher",
                "source_url", "checked_at", "valid_from", "valid_until", "summary", "is_demo"];
    for key in required {
        if key not in record {
            raise ContextValidationError("missing access notice field: " + key);
        }
    }
    for key in ["source_id", "external_id", "location_slug", "version", "publisher", "summary"] {
        if not isinstance(record[key], str) or not record[key].strip() {
            raise ContextValidationError("access notice " + key + " must be a non-empty string");
        }
    }
    if not isinstance(record["is_demo"], bool) {
        raise ContextValidationError("access notice is_demo must be boolean");
    }
    if not isinstance(record["source_url"], str) or (not record["is_demo"] and not record["source_url"].strip()) {
        raise ContextValidationError("source_url is required unless the fixture is explicitly simulated");
    }
    for key in ["checked_at", "valid_from", "valid_until"] {
        if isinstance(record[key], bool) or not isinstance(record[key], (int, float)) or not math.isfinite(float(record[key])) {
            raise ContextValidationError("access notice " + key + " must be a finite timestamp");
        }
    }
    if record["valid_until"] <= record["valid_from"] {
        raise ContextValidationError("access notice validity interval must be increasing");
    }
    if "entrance_instruction" in record and not isinstance(record["entrance_instruction"], str) {
        raise ContextValidationError("entrance_instruction must be text when present");
    }
}


"""Validate, resolve, then atomically create or refresh one source notice.

    Identity is the stable ``(source_id, external_id)`` pair. Every validation
    and location lookup happens before graph mutation, so bad input leaves the
    existing graph untouched. A source refresh failure should simply not call
    this function; that preserves the last successful checked timestamp.
"""
def upsert_access_notice(record: dict) -> str {
    _validate_access_notice(record);
    loc = _notice_location(record["location_slug"]);
    matches = [root-->[?:ContextNotice, source_id == record["source_id"], external_id == record["external_id"]]];
    if len(matches) > 1 {
        raise ContextValidationError("ambiguous source/external notice identity");
    }
    notice: ContextNotice;
    if matches {
        notice = matches[0];
        affected = [notice ->:Affects:->];
        if affected and jid(affected[0]) != jid(loc) {
            raise ContextValidationError("a notice identity cannot be silently moved to another location");
        }
        notice.version = record["version"];
        notice.summary = record["summary"];
        notice.publisher = record["publisher"];
        notice.source_url = record["source_url"];
        notice.checked_at = float(record["checked_at"]);
        notice.valid_from = float(record["valid_from"]);
        notice.valid_until = float(record["valid_until"]);
        notice.is_demo = record["is_demo"];
        notice.entrance_instruction = record.get("entrance_instruction", "");
        notice.original_evidence = record.get("original_evidence", record);
        notice.normalized_evidence = record.get("normalized_evidence", {});
        if not affected {
            notice +>:Affects():+> loc;
        }
    } else {
        notice = ContextNotice(
            source_id=record["source_id"], external_id=record["external_id"],
            version=record["version"], summary=record["summary"],
            publisher=record["publisher"], source_url=record["source_url"],
            checked_at=float(record["checked_at"]), valid_from=float(record["valid_from"]),
            valid_until=float(record["valid_until"]), is_demo=record["is_demo"],
            entrance_instruction=record.get("entrance_instruction", ""),
            original_evidence=record.get("original_evidence", record),
            normalized_evidence=record.get("normalized_evidence", {})
        );
        root ++> notice;
        notice +>:Affects():+> loc;
    }
    return jid(notice);
}


"""Small reviewed-JSON adapter; callers retain failed source records separately."""
def import_access_notices(records: list[dict]) -> list[str] {
    return [upsert_access_notice(record) for record in records];
}


"""Create one restaurant (with location, menu and offers) from a plain record.

Record keys: slug, name, cuisine, blurb, is_demo, source,
location{address, neighborhood, entrance_note, note_date},
menu[{name, price, dietary}], offers[{title, description, price, regular_price,
start_in_h, end_in_h, quantity, eligibility, terms, dietary, menu_item, status}].
Returns the restaurant, or the existing one if the slug is already present.
"""
def import_restaurant(record: dict) -> Restaurant {
    _reject_untrusted_identity_fields(record);
    existing = [root-->[?:Restaurant, slug == record["slug"]]];
    if existing {
        return existing[0];
    }
    now = time.time();
    r = Restaurant(
        slug=record["slug"],
        name=record["name"],
        cuisine=record.get("cuisine", ""),
        blurb=record.get("blurb", ""),
        is_demo=record.get("is_demo", False),
        source=record.get("source", "manual")
    );
    root ++> r;
    loc: dict = record.get("location", {});
    r +>:HasLocation():+> Location(
        address=loc.get("address", ""),
        neighborhood=loc.get("neighborhood", ""),
        entrance_note=loc.get("entrance_note", ""),
        note_date=loc.get("note_date", "")
    );
    items: dict = {};
    menu: list[dict] = record.get("menu", []);
    offers: list[dict] = record.get("offers", []);
    for m in menu {
        item = MenuItem(
            name=m["name"], price=float(m.get("price", 0)), dietary=m.get("dietary", [])
        );
        r +>:Serves():+> item;
        items[m["name"]] = item;
    }
    for o in offers {
        offer = Offer(
            title=o["title"],
            description=o.get("description", ""),
            price=float(o.get("price", 0)),
            regular_price=float(o.get("regular_price", 0)),
            start_ts=now + float(o.get("start_in_h", 0)) * 3600,
            end_ts=now + float(o.get("end_in_h", 4)) * 3600,
            quantity=int(o.get("quantity", 10)),
            eligibility=o.get("eligibility", "Any student with a valid student ID"),
            terms=o.get("terms", ""),
            dietary=o.get("dietary", []),
            status=o.get("status", "active"),
            is_demo=record.get("is_demo", False),
            menu_item=o.get("menu_item", ""),
            created_ts=now
        );
        r +>:Publishes():+> offer;
        name = o.get("menu_item", "");
        if name and name in items {
            offer +>:Features():+> items[name];
        }
    }
    return r;
}
