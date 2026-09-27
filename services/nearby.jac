"""What now? Nearby places to go after a redeemed claim.

Places are grouped as activities, coffee, dessert and bars, each with its
walking distance from the place the student just visited. Within a group the
nearest place comes first and at most four are shown. A place with a live
deal in the app says so and links to it; when one is within a walk but not
among the nearest four, it takes the fourth spot.

Sample places appear only when the server turns demo mode on. Reading this
never writes anything and never records who looked.
"""

import os;
import math;
import time;
import hashlib;
import from services.models { Restaurant, Publishes }
import from services.qr_catalog { _ensure_seed }
import from services.promo { _state, _remaining, _find_offer, _restaurant_of, _location_of }
import from services.taste { categories_for }
import from services.nearby_data { AREA_CENTERS, DEFAULT_AREA, SAMPLE_PLACES }


glob:pub KINDS: list[list[str]] = [
    ["activity", "Activities"], ["coffee", "Coffee"], ["dessert", "Dessert"], ["bars", "Bars"]
];

glob:pub MAX_METERS: float = 1300.0;

glob:pub MAX_PER_KIND: int = 4;

glob:pub METERS_PER_MINUTE: float = 80.0;

glob DEMO_MODE: str = "MLOCAL_DEMO_MODE";


obj NearbyCard {
    has name: str = "",
        kind: str = "",
        what: str = "",
        meters: int = 0,
        distance: str = "",
        minutes: int = 0,
        deal: str = "",
        deal_offer_id: str = "",
        is_sample: bool = False,
        adults_only: bool = False;
}

obj NearbyGroup {
    has kind: str = "",
        label: str = "",
        cards: list[NearbyCard] = [];
}

obj NearbyView {
    has ok: bool = False,
        heading: str = "What now?",
        origin: str = "",
        has_samples: bool = False,
        groups: list[NearbyGroup] = [],
        note: str = "";
}


def samples_on(text: str) -> bool {
    return text.strip().lower() in ["1", "true", "yes", "on"];
}


def meters_between(lat1: float, lng1: float, lat2: float, lng2: float) -> float {
    radius = 6371000.0;
    p1 = math.radians(lat1);
    p2 = math.radians(lat2);
    dp = math.radians(lat2 - lat1);
    dl = math.radians(lng2 - lng1);
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2;
    return 2 * radius * math.asin(min(1.0, math.sqrt(a)));
}


def distance_label(meters: float) -> str {
    miles = meters / 1609.344;
    return "under 0.1 mi" if miles < 0.1 else f"{miles:.1f} mi";
}


def walk_minutes(meters: float) -> int {
    return max(1, int(round(meters / METERS_PER_MINUTE)));
}


def center_of(neighborhood: str) -> list[float] {
    return AREA_CENTERS.get(neighborhood.strip().lower(), AREA_CENTERS[DEFAULT_AREA]);
}


"""A steady, invented position for a listed place: its neighborhood's center
moved by up to about 150 meters, the same every time for the same place."""
def position_of(slug: str, neighborhood: str) -> list[float] {
    center = center_of(neighborhood);
    digest = hashlib.sha256(slug.encode()).hexdigest();
    north = (int(digest[:4], 16) / 65535.0 - 0.5) * 300.0;
    east = (int(digest[4:8], 16) / 65535.0 - 0.5) * 300.0;
    return [center[0] + north / 111320.0, center[1] + east / (111320.0 * math.cos(math.radians(center[0])))];
}


def kind_for(cuisine: str, title: str) -> str {
    found = categories_for(cuisine, title);
    if "coffee" in found {
        return "coffee";
    }
    if "dessert" in found or "bakery" in found {
        return "dessert";
    }
    return "";
}


def _card(kind: str, what: str, name: str, meters: float, deal: str = "", offer_id: str = "", sample: bool = False) -> NearbyCard {
    return NearbyCard(
        name=name, kind=kind, what=what, meters=int(round(meters)), distance=distance_label(meters),
        minutes=walk_minutes(meters), deal=deal, deal_offer_id=offer_id, is_sample=sample, adults_only=kind == "bars"
    );
}


def sample_cards(lat: float, lng: float) -> list[NearbyCard] {
    out: list[NearbyCard] = [];
    for row in SAMPLE_PLACES {
        meters = meters_between(lat, lng, float(row[3]), float(row[4]));
        out.append(_card(str(row[0]), str(row[1]), str(row[2]), meters, ("Sample deal: " + str(row[5])) if row[5] else "", "", True));
    }
    return out;
}


def _price(cents: int) -> str {
    return f"${cents // 100}" + ("" if cents % 100 == 0 else f".{cents % 100:02d}");
}


"""Listed places with a deal running right now, other than the one just
visited. Sample listings are left out unless demo mode is on."""
def listed_cards(origin_slug: str, lat: float, lng: float, now: float, samples: bool) -> list[NearbyCard] {
    out: list[NearbyCard] = [];
    for r in [root.shared -->[?:Restaurant]] {
        if r.slug == origin_slug or (r.is_demo and not samples) {
            continue;
        }
        live = [o for o in [r ->:Publishes:->] if _state(o, now) == "active" and _remaining(o, now) > 0 and (samples or not o.is_demo)];
        if not live {
            continue;
        }
        best = sorted(live, key=lambda (o: any) -> int { return int(o.price_cents); })[0];
        kind = kind_for(r.cuisine, best.title);
        if not kind {
            continue;
        }
        loc = _location_of(r);
        spot = position_of(r.slug, loc.neighborhood if loc else "");
        out.append(_card(
            kind, r.cuisine or "Listed place", r.name, meters_between(lat, lng, spot[0], spot[1]),
            f"Deal on now: {best.title}" + (f" ({_price(best.price_cents)})" if best.price_cents >= 0 and _price(best.price_cents) not in best.title else ""),
            jid(best), r.is_demo
        ));
    }
    return out;
}


"""The nearest places, with room kept for one that has a live deal."""
def nearest(cards: list[NearbyCard], most: int) -> list[NearbyCard] {
    kept = cards[:most];
    if most > 0 and len(cards) > most and not [c for c in kept if c.deal_offer_id] {
        listed = [c for c in cards[most:] if c.deal_offer_id];
        if listed {
            kept = kept[:most - 1] + [listed[0]];
        }
    }
    return kept;
}


"""Group, keep what is within a walk, and put the nearest first."""
def build_groups(cards: list[NearbyCard]) -> list[NearbyGroup] {
    out: list[NearbyGroup] = [];
    for pair in KINDS {
        mine = [c for c in cards if c.kind == pair[0] and c.meters <= MAX_METERS];
        mine = sorted(mine, key=lambda (c: NearbyCard) -> tuple[int, str] { return (c.meters, c.name); });
        if mine {
            out.append(NearbyGroup(kind=pair[0], label=pair[1], cards=nearest(mine, MAX_PER_KIND)));
        }
    }
    return out;
}


def _nearby(offer_id: str, now: float, samples: bool) -> NearbyView {
    o = _find_offer(offer_id);
    r = _restaurant_of(o) if o is not None else None;
    if o is None or r is None {
        return NearbyView(note="That offer no longer exists.");
    }
    loc = _location_of(r);
    here = position_of(r.slug, loc.neighborhood if loc else "");
    cards = listed_cards(r.slug, here[0], here[1], now, samples);
    if samples {
        cards += sample_cards(here[0], here[1]);
    }
    groups = build_groups(cards);
    if not groups {
        return NearbyView(origin=r.name, note="No nearby places are listed yet.");
    }
    return NearbyView(
        ok=True, origin=r.name, groups=groups,
        has_samples=any([c.is_sample for g in groups for c in g.cards]),
        note="Sample places with invented distances and deals." if samples else ""
    );
}


"""Nearby places to go after the offer's place, for the What now? cards."""
def:pub nearby_after(offer_id: str) -> NearbyView {
    _ensure_seed();
    return _nearby(offer_id, time.time(), samples_on(os.environ.get(DEMO_MODE, "")));
}
