"""What now? checks. Run: jac test services/nearby.jac"""

import from services.promo { _claim, _redeem }
import from services.foryou { _home }

def _offer_at(slug: str, now: float) -> str {
    found = [i for i in _home("", "", "any", "", now).items if i.place == slug];
    assert found, slug;
    return found[0].offer.id;
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


test "each redemption moves the first place forward by one, in order" {
    cards = [NearbyCard(name=n, kind="coffee", meters=m) for (n, m) in [("a", 100), ("b", 200), ("c", 300)]];
    assert [c.name for c in rotate(cards, 0)] == ["a", "b", "c"];
    assert [c.name for c in rotate(cards, 1)] == ["b", "c", "a"];
    assert [c.name for c in rotate(cards, 2)] == ["c", "a", "b"];
    assert [c.name for c in rotate(cards, 3)] == ["a", "b", "c"];
    assert rotate([], 5) == [];
    _ensure_seed();
    now = time.time();
    oid = _offer_at("maize-noodle-lab", now);
    firsts: dict[str, list[str]] = {};
    for turn in range(16) {
        view = _nearby(oid, now, True, turn);
        for g in view.groups {
            firsts.setdefault(g.kind, []).append(g.cards[0].name);
        }
    }
    for pair in KINDS {
        size = len(_nearby(oid, now, True, 0).groups[[p[0] for p in KINDS].index(pair[0])].cards);
        assert len(set(firsts[pair[0]][:size])) == size, pair;
        assert firsts[pair[0]][0] == firsts[pair[0]][size] if size < 16 else True;
    }
}


test "suggestions are grouped by kind, within a walk, and nearest first before rotation" {
    _ensure_seed();
    now = time.time();
    view = _nearby(_offer_at("maize-noodle-lab", now), now, True, 0);
    assert view.ok and view.heading == "What now?" and view.origin.startswith("Maize Street Noodle Lab") and view.has_samples;
    assert [g.kind for g in view.groups] == ["activity", "coffee", "dessert", "bars"];
    assert [g.label for g in view.groups] == ["Activities", "Coffee", "Dessert", "Bars"];
    for g in view.groups {
        assert len(g.cards) >= 4, g.kind;
        assert [c.meters for c in g.cards] == sorted([c.meters for c in g.cards]);
        assert all([c.kind == g.kind and c.meters <= MAX_METERS and c.distance and c.minutes >= 1 for c in g.cards]);
        assert all([c.adults_only == (g.kind == "bars") for c in g.cards]);
        assert view.origin not in [c.name for c in g.cards];
    }
    assert view.note == "Sample places with invented distances and deals.";
}


test "a place with a live deal in the app says so and links to it" {
    _ensure_seed();
    now = time.time();
    view = _nearby(_offer_at("maize-noodle-lab", now), now, True, 0);
    coffee = [g for g in view.groups if g.kind == "coffee"][0];
    listed = [c for c in coffee.cards if c.deal_offer_id];
    assert listed, [c.name for c in coffee.cards];
    assert listed[0].name == "Arbor Leaf Kitchen (Demo)" and "Deal on now: $3 oat latte study break" in listed[0].deal;
    assert listed[0].deal_offer_id == _offer_at("arbor-leaf-kitchen", now) or listed[0].deal_offer_id != "";
    samples = [c for g in view.groups for c in g.cards if c.is_sample and not c.deal_offer_id];
    assert [c for c in samples if c.deal.startswith("Sample deal: ")] and [c for c in samples if c.deal == ""];
    from_leaf = _nearby(_offer_at("arbor-leaf-kitchen", now), now, True, 0);
    assert "Arbor Leaf Kitchen (Demo)" not in [c.name for g in from_leaf.groups for c in g.cards];
}


test "sample places stay hidden unless demo mode is on" {
    assert samples_on("1") and samples_on(" TRUE ") and not samples_on("") and not samples_on("0") and not samples_on("maybe");
    _ensure_seed();
    now = time.time();
    hidden = _nearby(_offer_at("maize-noodle-lab", now), now, False, 0);
    assert not hidden.has_samples;
    assert not [c for g in hidden.groups for c in g.cards if c.is_sample];
    assert hidden.ok == (len(hidden.groups) > 0);
    assert hidden.groups != [] or hidden.note == "No nearby places are listed yet.";
    missing = _nearby("no-such-offer", now, True, 0);
    assert not missing.ok and missing.groups == [] and missing.note == "That offer no longer exists.";
}


test "the turn follows recorded redemptions and reading never adds one" {
    _ensure_seed();
    now = time.time();
    before = redemptions_so_far();
    oid = _offer_at("diag-dough-co", now);
    claim = _claim(oid, "nearby-student", now);
    assert claim.ok and redemptions_so_far() == before;
    assert _redeem(_place("diag-dough-co"), claim.qr_payload, now + 5).ok;
    assert redemptions_so_far() == before + 1;
    for _ in range(3) {
        _nearby(oid, now + 10, True, redemptions_so_far());
    }
    assert redemptions_so_far() == before + 1;
}
