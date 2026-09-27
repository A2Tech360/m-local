"""What now? checks. Run: jac test services/nearby.jac"""

import from services.promo { _claim, _redeem }
import from services.models { ClaimedAs, Offer, Publishes }
import from services.foryou { _home }

def _offer_at(slug: str, now: float) -> str {
    found = [i for i in _home("", "", "any", "", now).items if i.place == slug];
    assert found, slug;
    return found[0].offer.id;
}


def _where(slug: str) -> str {
    loc = _location_of(_place(slug));
    return loc.neighborhood if loc else "";
}


def _place(slug: str) -> Restaurant {
    return [r for r in [root.shared -->[?:Restaurant]] if r.slug == slug][0];
}


test "distances read in miles and walking minutes" {
    assert distance_label(100.0) == "350 ft" and distance_label(161.0) == "0.1 mi";
    assert distance_label(3.0) == "50 ft" and distance_label(60.0) == "200 ft" and distance_label(155.0) == "500 ft";
    assert distance_label(402.0) == "0.2 mi" and distance_label(1609.344) == "1.0 mi";
    assert walk_minutes(10.0) == 1 and walk_minutes(400.0) == 5 and walk_minutes(1000.0) == 12;
    assert abs(meters_between(42.0, -83.0, 43.0, -83.0) - 111195.0) < 100.0;
    assert center_of(" Kerrytown ") == [42.2850, -83.7470] and center_of("Nowhere") == center_of("central campus");
    assert position_of("a-place", "Kerrytown") == position_of("a-place", "Kerrytown");
    assert meters_between(42.2850, -83.7470, position_of("a-place", "Kerrytown")[0], position_of("a-place", "Kerrytown")[1]) < 215.0;
}


test "the sample set is labeled, varied and inside Ann Arbor" {
    for pair in KINDS {
        rows = [r for r in SAMPLE_PLACES if r[0] == pair[0]];
        assert len(rows) == 8, pair;
        assert len(set([str(r[2]) for r in rows])) == 8;
        assert len([r for r in rows if r[5]]) >= 2 and len([r for r in rows if not r[5]]) >= 2;
    }
    assert len(SAMPLE_PLACES) == 32 and len(set([str(r[2]) for r in SAMPLE_PLACES])) == 32;
    for r in SAMPLE_PLACES {
        assert str(r[2]).endswith("(Sample)") and str(r[1]);
        assert float(r[3]) > 42.26 and float(r[3]) < 42.31 and float(r[4]) > -83.77 and float(r[4]) < -83.70;
    }
}


test "the nearest place is first in every kind, from any starting place" {
    _ensure_seed();
    now = time.time();
    firsts: list[str] = [];
    for slug in ["maize-noodle-lab", "arbor-leaf-kitchen", "diag-dough-co"] {
        view = _nearby(_offer_at(slug, now), now, True);
        assert [g.kind for g in view.groups] == ["activity", "coffee", "dessert", "bars"];
        for g in view.groups {
            assert [c.meters for c in g.cards] == sorted([c.meters for c in g.cards]), [slug, g.kind];
            assert len(g.cards) == 4, [slug, g.kind, len(g.cards)];
            everything = sorted([c.meters for c in sample_cards(position_of(slug, _where(slug))[0], position_of(slug, _where(slug))[1]) if c.kind == g.kind]);
            assert g.cards[0].meters <= everything[0];
            assert [c.meters for c in g.cards if not c.deal_offer_id] == [m for m in everything if m <= g.cards[-1].meters][:len([c for c in g.cards if not c.deal_offer_id])];
        }
        again = _nearby(_offer_at(slug, now), now, True);
        assert [[c.name for c in g.cards] for g in again.groups] == [[c.name for c in g.cards] for g in view.groups];
        firsts.append(view.groups[0].cards[0].name + "/" + view.groups[1].cards[0].name);
    }
    assert len(set(firsts)) >= 2, firsts;
}


test "suggestions are grouped by kind and within a walk" {
    _ensure_seed();
    now = time.time();
    view = _nearby(_offer_at("maize-noodle-lab", now), now, True);
    assert view.ok and view.heading == "What now?" and view.origin.startswith("Maize Street Noodle Lab") and view.has_samples;
    assert [g.kind for g in view.groups] == ["activity", "coffee", "dessert", "bars"];
    assert [g.label for g in view.groups] == ["Activities", "Coffee", "Dessert", "Bars"];
    for g in view.groups {
        assert len(g.cards) == MAX_PER_KIND, g.kind;
        assert [c.meters for c in g.cards] == sorted([c.meters for c in g.cards]);
        assert all([c.kind == g.kind and c.meters <= MAX_METERS and c.distance and c.minutes >= 1 for c in g.cards]);
        assert all([c.adults_only == (g.kind == "bars") for c in g.cards]);
        assert view.origin not in [c.name for c in g.cards];
    }
    assert view.note == "Sample places with invented distances and deals.";
}


test "at most four are kept, nearest first, with room for one live deal" {
    far = [NearbyCard(name=str(m), kind="coffee", meters=m) for m in [100, 200, 300, 400, 500, 600]];
    assert [c.meters for c in nearest(far, 4)] == [100, 200, 300, 400];
    assert [c.meters for c in nearest(far[:3], 4)] == [100, 200, 300] and nearest([], 4) == [];
    far[5].deal_offer_id = "live";
    assert [c.meters for c in nearest(far, 4)] == [100, 200, 300, 600];
    far[1].deal_offer_id = "closer";
    assert [c.meters for c in nearest(far, 4)] == [100, 200, 300, 400];
}


test "a place with a live deal in the app says so and links to it" {
    _ensure_seed();
    now = time.time();
    view = _nearby(_offer_at("maize-noodle-lab", now), now, True);
    coffee = [g for g in view.groups if g.kind == "coffee"][0];
    listed = [c for c in coffee.cards if c.deal_offer_id];
    assert listed, [c.name for c in coffee.cards];
    assert listed[0].name == "Arbor Leaf Kitchen (Demo)" and "Deal on now: $3 oat latte study break" in listed[0].deal;
    assert listed[0].deal_offer_id == _offer_at("arbor-leaf-kitchen", now) or listed[0].deal_offer_id != "";
    samples = [c for g in view.groups for c in g.cards if c.is_sample and not c.deal_offer_id];
    assert [c for c in samples if c.deal.startswith("Sample deal: ")] and [c for c in samples if c.deal == ""];
    from_leaf = _nearby(_offer_at("arbor-leaf-kitchen", now), now, True);
    assert "Arbor Leaf Kitchen (Demo)" not in [c.name for g in from_leaf.groups for c in g.cards];
}


test "sample places stay hidden unless demo mode is on" {
    assert samples_on("1") and samples_on(" TRUE ") and not samples_on("") and not samples_on("0") and not samples_on("maybe");
    _ensure_seed();
    now = time.time();
    hidden = _nearby(_offer_at("maize-noodle-lab", now), now, False);
    assert not hidden.has_samples;
    assert not [c for g in hidden.groups for c in g.cards if c.is_sample];
    assert hidden.ok == (len(hidden.groups) > 0);
    assert hidden.groups == [] and not hidden.ok;
    missing = _nearby("no-such-offer", now, True);
    assert not missing.ok and missing.groups == [] and missing.note == "That offer no longer exists.";
}


test "reading the suggestions changes nothing" {
    _ensure_seed();
    now = time.time();
    oid = _offer_at("diag-dough-co", now);
    claim = _claim(oid, "nearby-student", now);
    assert claim.ok and _redeem(_place("diag-dough-co"), claim.qr_payload, now + 5).ok;
    before = [[o.title, o.quantity, len([c for c in [o ->:ClaimedAs:->]])] for r in [root.shared -->[?:Restaurant]] for o in [r ->:Publishes:->]];
    places = len([r for r in [root.shared -->[?:Restaurant]]]);
    for _ in range(3) {
        assert _nearby(oid, now + 10, True).ok;
    }
    assert before == [[o.title, o.quantity, len([c for c in [o ->:ClaimedAs:->]])] for r in [root.shared -->[?:Restaurant]] for o in [r ->:Publishes:->]];
    assert places == len([r for r in [root.shared -->[?:Restaurant]]]);
}

test "unverified real locations never produce walking suggestions" {
    _ensure_seed();
    now = time.time();
    oid = _offer_at("maize-noodle-lab", now);
    cafe = _place("arbor-leaf-kitchen");
    origin = _place("maize-noodle-lab");
    cafe_offer = _find_offer(_offer_at("arbor-leaf-kitchen", now));
    origin_offer = _find_offer(oid);
    assert cafe_offer is not None and origin_offer is not None;
    original_cafe_offer_demo = cafe_offer.is_demo;
    original_origin_offer_demo = origin_offer.is_demo;
    original_cafe_demo = cafe.is_demo;
    original_origin_demo = origin.is_demo;
    try {
        cafe.is_demo = False;
        live = _nearby(oid, now, False);
        assert not live.ok and live.groups == [];
        demo = _nearby(oid, now, True);
        assert demo.ok;
        assert cafe.name not in [c.name for g in demo.groups for c in g.cards];
        cafe.is_demo = True;
        cafe_offer.is_demo = False;
        mixed = _nearby(oid, now, True);
        assert jid(cafe_offer) not in [c.deal_offer_id for g in mixed.groups for c in g.cards];
        origin_offer.is_demo = False;
        assert not _nearby(oid, now, True).ok;
        origin_offer.is_demo = original_origin_offer_demo;
        origin.is_demo = False;
        real_origin = _nearby(oid, now, True);
        assert not real_origin.ok and real_origin.groups == [];
    } finally {
        cafe_offer.is_demo = original_cafe_offer_demo;
        origin_offer.is_demo = original_origin_offer_demo;
        cafe.is_demo = original_cafe_demo;
        origin.is_demo = original_origin_demo;
    }
}


def _add_place(identity: str, name: str, category: str, lat: float, lon: float, flags: list[str] = []) -> Place {
    p = Place(
        place_id=identity, name=name, category=category, lat=lat, lon=lon, source_id=identity, source_type="node",
        source_url="https://www.openstreetmap.org/" + identity, coordinate_method="osm_node",
        retrieved_at="2026-09-27T00:00:00Z", categories=[category], quality_flags=flags
    );
    root.shared ++> p;
    return p;
}


def _clear_places {
    for r in [root.shared -->[?:Restaurant]] {
        for loc in [r ->:HasLocation:->] {
            for e in [edge loc ->:LocatedAt:->] {
                del e;
            }
        }
    }
    for p in [root.shared -->[?:Place]] {
        del p;
    }
}


def _link(slug: str, p: Place) {
    loc = _location_of(_place(slug));
    assert loc is not None;
    loc +>:LocatedAt():+> p;
}


test "a restaurant linked to a catalog place gets real places measured from its recorded position" {
    _ensure_seed();
    _clear_places();
    now = time.time();
    _link("maize-noodle-lab", _add_place("osm:node:1", "Noodle Lab Building", "restaurant", 42.2800, -83.7400));
    _add_place("osm:node:2", "Near Cafe", "cafe", 42.2805, -83.7400);
    _add_place("osm:node:3", "Far Cafe", "cafe", 42.2860, -83.7400);
    _add_place("osm:node:4", "Too Far Cafe", "cafe", 42.3000, -83.7400);
    _add_place("osm:node:5", "Closed Campus Cafe", "cafe", 42.2801, -83.7400, ["restricted_access_tag"]);
    _add_place("osm:node:6", "Corner Bookshop", "bookshop", 42.2810, -83.7410);
    _add_place("osm:node:7", "Tree Park", "park", 42.2790, -83.7390);
    _add_place("osm:node:8", "Gelato Stop", "ice_cream", 42.2803, -83.7395);
    _add_place("osm:node:9", "Old Pub", "pub", 42.2795, -83.7405);
    _add_place("osm:node:10", "City Hall", "townhall", 42.2801, -83.7401);
    _add_place("osm:node:11", "Another Restaurant", "restaurant", 42.2802, -83.7402);
    for samples in [False, True] {
        view = _nearby(_offer_at("maize-noodle-lab", now), now, samples);
        assert view.ok and view.from_catalog and not view.has_samples and not view.sample_deals, samples;
        assert view.attribution == ATTRIBUTION and "OpenStreetMap" in view.attribution and view.note == "";
        names = {g.kind: [c.name for c in g.cards] for g in view.groups};
        assert [g.kind for g in view.groups] == ["activity", "coffee", "dessert", "bars"];
        assert names["coffee"] == ["Near Cafe", "Far Cafe"], names;
        assert sorted(names["activity"]) == ["Corner Bookshop", "Tree Park"];
        assert names["dessert"] == ["Gelato Stop"] and names["bars"] == ["Old Pub"];
        everyone = [c.name for g in view.groups for c in g.cards];
        for hidden in ["Noodle Lab Building", "City Hall", "Another Restaurant", "Too Far Cafe", "Closed Campus Cafe"] {
            assert hidden not in everyone, hidden;
        }
        assert not [c for g in view.groups for c in g.cards if c.is_sample or c.name.endswith("(Sample)")];
    }
    view = _nearby(_offer_at("maize-noodle-lab", now), now, False);
    near = [c for g in view.groups for c in g.cards if c.name == "Near Cafe"][0];
    assert abs(near.meters - 56) <= 2 and near.distance == "200 ft" and near.minutes == 1 and near.what == "Cafe", near;
    far = [c for g in view.groups for c in g.cards if c.name == "Far Cafe"][0];
    assert abs(far.meters - 667) <= 3 and far.distance == "0.4 mi" and far.minutes == 8, far;
    tavern = [c for g in view.groups for c in g.cards if c.name == "Old Pub"][0];
    assert tavern.adults_only and tavern.what == "Pub";
    _clear_places();
}


test "a catalog place whose restaurant has a live deal names it, and demo deals need demo mode" {
    _ensure_seed();
    _clear_places();
    now = time.time();
    _link("maize-noodle-lab", _add_place("osm:node:1", "Noodle Lab Building", "restaurant", 42.2800, -83.7400));
    _link("arbor-leaf-kitchen", _add_place("osm:node:20", "Arbor Leaf Cafe Building", "cafe", 42.2840, -83.7400));
    for i in range(5) {
        _add_place(f"osm:node:{30 + i}", f"Closer Cafe {i}", "cafe", 42.2802 + i * 0.0002, -83.7400);
    }
    shown = _nearby(_offer_at("maize-noodle-lab", now), now, True);
    coffee = [g for g in shown.groups if g.kind == "coffee"][0];
    assert [c.name for c in coffee.cards] == ["Closer Cafe 0", "Closer Cafe 1", "Closer Cafe 2", "Arbor Leaf Cafe Building"], [c.name for c in coffee.cards];
    assert coffee.cards[3].deal.startswith("Deal on now: ") and coffee.cards[3].deal_offer_id != "";
    assert coffee.cards[3].sample_deal and shown.sample_deals and not shown.has_samples;
    assert len([c for g in shown.groups for c in g.cards if c.deal_offer_id]) == 1;
    hidden = _nearby(_offer_at("maize-noodle-lab", now), now, False);
    quiet = [g for g in hidden.groups if g.kind == "coffee"][0];
    assert [c.name for c in quiet.cards] == ["Closer Cafe 0", "Closer Cafe 1", "Closer Cafe 2", "Closer Cafe 3"];
    assert not [c for c in quiet.cards if c.deal] and not hidden.sample_deals and hidden.from_catalog;
    hosted = _nearby(_offer_at("maize-noodle-lab", now), now, False, True);
    assert [c.name for c in [g for g in hosted.groups if g.kind == "coffee"][0].cards][3] == "Arbor Leaf Cafe Building" and hosted.sample_deals;
    back = _nearby(_offer_at("arbor-leaf-kitchen", now), now, True);
    assert back.from_catalog and "Arbor Leaf Cafe Building" not in [c.name for g in back.groups for c in g.cards];
    _clear_places();
}


test "a linked restaurant with nothing in range says so, and an unlinked one keeps the earlier rules" {
    _ensure_seed();
    _clear_places();
    now = time.time();
    _link("maize-noodle-lab", _add_place("osm:node:1", "Noodle Lab Building", "restaurant", 42.2800, -83.7400));
    _add_place("osm:node:50", "Distant Cafe", "cafe", 42.3300, -83.7400);
    alone = _nearby(_offer_at("maize-noodle-lab", now), now, True);
    assert not alone.ok and alone.groups == [] and alone.from_catalog and alone.note == "No places are recorded within a short walk.";
    unlinked = _nearby(_offer_at("arbor-leaf-kitchen", now), now, True);
    assert unlinked.ok and not unlinked.from_catalog and unlinked.has_samples and unlinked.attribution == "";
    assert "Distant Cafe" not in [c.name for g in unlinked.groups for c in g.cards];
    for dataset in [False, True] {
        refused = _nearby(_offer_at("arbor-leaf-kitchen", now), now, False, dataset);
        assert not refused.ok and refused.groups == [] and not refused.from_catalog, dataset;
    }
    _clear_places();
    plain = _nearby(_offer_at("maize-noodle-lab", now), now, True);
    assert plain.ok and not plain.from_catalog and plain.has_samples;
}
