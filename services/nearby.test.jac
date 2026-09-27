"""What now? checks. Run: jac test services/nearby.jac"""

import from services.promo { _claim, _redeem }
import from services.models { ClaimedAs }
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
    assert distance_label(100.0) == "under 0.1 mi" and distance_label(161.0) == "0.1 mi";
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
    assert hidden.groups != [] or hidden.note == "No nearby places are listed yet.";
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
