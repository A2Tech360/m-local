"""Saved tastes, favorites and home feed checks. Run: jac test services/foryou.jac

Outside a served request there is one root, so the caller's identity is passed
to the internal helpers. Privacy between real accounts is checked over HTTP."""

import from services.promo { _claim, _redeem }
import from services.session { _merchant_for_actor }

def _reset -> TasteProfile {
    for p in [root -->[?:TasteProfile]] {
        for f in [p ->:Keeps:->] {
            del f;
        }
        del p;
    }
    fresh = _profile(True);
    assert fresh is not None;
    return fresh as TasteProfile;
}


def _titles(h: HomeView) -> list[str] {
    return [i.offer.title for i in h.items];
}


def _seeded(h: HomeView) -> list[str] {
    known = ["Lunch noodle bowl for $7", "Late-night dumplings, 2 for 1", "Harvest bowl for $8",
             "$3 oat latte study break", "Slice + drink for $5"];
    return sorted([t for t in _titles(h) if t in known]);
}


test "tastes are cleaned, saved and listed with every choice" {
    _ensure_seed();
    _reset();
    before = _taste_view(_profile(), True);
    assert not before.completed and before.categories == [];
    assert len(before.all_categories) == 14 and len(before.all_diets) == 4 and len(before.all_price_ranges) == 4;
    assert before.all_price_ranges[1].label == "$5 to $8";
    saved = _save_taste("Pizza, noodles , lasers,pizza", "VEGAN,keto", "5to8", time.time());
    assert saved.ok and saved.completed;
    assert saved.categories == ["noodles", "pizza"] and saved.diets == ["vegan"] and saved.price_range == "5to8";
    assert _save_taste("", "", "free", time.time()).price_range == "";
    cleared = _save_taste("", "", "", time.time());
    assert cleared.completed and cleared.categories == [] and cleared.diets == [];
}


test "favorites toggle on and off and unknown places are refused" {
    _ensure_seed();
    _reset();
    on = _toggle_favorite("arbor-leaf-kitchen", time.time());
    assert on.ok and on.favorites == ["arbor-leaf-kitchen"] and on.message == "Added to favorites.";
    two = _toggle_favorite("diag-dough-co", time.time() + 1);
    assert two.favorites == ["diag-dough-co", "arbor-leaf-kitchen"];
    off = _toggle_favorite("arbor-leaf-kitchen", time.time() + 2);
    assert off.ok and off.favorites == ["diag-dough-co"] and off.message == "Removed from favorites.";
    bad = _toggle_favorite("no-such-place", time.time());
    assert not bad.ok and bad.favorites == ["diag-dough-co"];
    assert not _toggle_favorite("", time.time()).ok;
}


test "a guest sees every live deal and no favorites" {
    _ensure_seed();
    _reset();
    h = _home("", "", "any", "", time.time());
    assert not h.signed_in and not h.personalized and h.favorites == [];
    assert _seeded(h) == sorted(["Lunch noodle bowl for $7", "Late-night dumplings, 2 for 1", "Harvest bowl for $8",
                                  "$3 oat latte study break", "Slice + drink for $5"]);
    assert "Weekend cheese slice deal" not in _titles(h);
    assert h.total_deals == len(h.items);
    assert all([i.slot == "more" for i in h.items]);
}


test "saved tastes reorder the feed but every deal is still there" {
    _ensure_seed();
    _reset();
    guest = _home("", "", "any", "", time.time());
    _save_taste("pizza", "", "", time.time());
    h = _home("student-pizza", "", "any", "", time.time());
    assert h.signed_in and h.personalized and h.completed;
    assert h.items[0].offer.title == "Slice + drink for $5";
    assert h.items[0].slot == "match" and "You like pizza" in h.items[0].reasons;
    assert h.items[0].categories == ["pizza"];
    assert sorted(_titles(h)) == sorted(_titles(guest));
    assert len([i for i in h.items if i.slot != "match"]) >= 4;
}


test "cards carry food labels for the deal and the place" {
    _ensure_seed();
    _reset();
    h = _home("", "", "any", "", time.time());
    bowl = [i for i in h.items if i.offer.title == "Harvest bowl for $8"][0];
    assert "vegan" in bowl.offer.dietary and "gluten-free" in bowl.offer.dietary;
    assert bowl.place == "arbor-leaf-kitchen";
    assert bowl.place_labels == ["Vegetarian", "Vegan", "Gluten-free options"];
    slice = [i for i in h.items if i.offer.title == "Slice + drink for $5"][0];
    assert slice.place_labels == ["Vegetarian options", "Halal options"];
    assert bowl.price_range == "5to8" and slice.price_range == "5to8";
}


test "price range and diet filters narrow the page, tastes do not" {
    _ensure_seed();
    _reset();
    everything = _home("", "", "any", "", time.time());
    cheap = _home("", "under5", "any", "", time.time());
    assert cheap.price_range == "under5" and len(cheap.items) >= 1;
    assert all([i.price_cents < 500 for i in cheap.items]);
    assert "$3 oat latte study break" in _titles(cheap);
    assert cheap.total_deals == everything.total_deals;
    mid = _home("", "5to8", "any", "", time.time());
    assert all([i.price_cents >= 500 and i.price_cents <= 800 for i in mid.items]);
    assert _home("", "nonsense", "any", "", time.time()).price_range == "";
    veg = _home("", "", "any", "vegetarian", time.time());
    assert "Harvest bowl for $8" in _titles(veg) and "Slice + drink for $5" not in _titles(veg);
    now_only = _home("", "", "now", "", time.time());
    assert "Late-night dumplings, 2 for 1" not in _titles(now_only);
    empty = _home("", "12plus", "any", "halal", time.time());
    assert empty.items == [] and empty.note != "";
}


test "favorites fill the strip and lead the feed" {
    _ensure_seed();
    _reset();
    _toggle_favorite("maize-noodle-lab", time.time());
    h = _home("student-fan", "", "any", "", time.time());
    assert len(h.favorites) == 1;
    fav = h.favorites[0];
    assert fav.name == "Maize Street Noodle Lab" and fav.slug == "maize-noodle-lab";
    assert fav.cuisine == "Noodles and dumplings" and fav.neighborhood == "State Street";
    assert fav.live_offers == 1 and fav.best_offer_title == "Lunch noodle bowl for $7" and fav.best_price_cents == 700;
    assert fav.best_offer_id == h.items[0].offer.id;
    assert h.items[0].slot == "favorite" and h.items[0].is_favorite;
    assert not [i for i in h.items if i.place != "maize-noodle-lab" and i.is_favorite];
}


test "claims and redemptions teach the feed without any saved tastes" {
    _ensure_seed();
    _reset();
    now = time.time();
    actor = "student-learner";
    offer = [i for i in _home("", "", "any", "", now).items if i.offer.title == "$3 oat latte study break"][0];
    assert _history(actor, now) == [];
    assert _claim(offer.offer.id, actor, now).ok;
    signals = _history(actor, now + 60);
    assert [s.category for s in signals] == ["coffee"] and signals[0].action == "claim";
    h = _home(actor, "", "any", "", now + 60);
    assert h.personalized and not h.completed;
    assert h.items[0].offer.title == "$3 oat latte study break";
    assert _history("someone-else", now + 60) == [];
}
