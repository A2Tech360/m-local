"""For you ranking checks. Run: jac test services/taste.jac"""

def _deal(
    oid: str, place: str, cats: list[str], price: int = 700, regular: int = 1000,
    dietary: list[str] = [], remaining: int = 10, hours: float = 5.0, rotation: int = 0
) -> Candidate {
    return Candidate(
        offer_id=oid, place=place, title=oid, categories=cats, dietary=dietary,
        price_cents=price, regular_cents=regular, remaining=remaining,
        ends_in_hours=hours, rotation=rotation
    );
}


def _menu -> list[Candidate] {
    return [
        _deal("noodle-1", "noodle-lab", ["noodles"], 700, 1150, ["vegetarian"]),
        _deal("pizza-1", "dough-co", ["pizza"], 500, 850, ["halal"]),
        _deal("bowl-1", "leaf-kitchen", ["bowls", "salads"], 800, 1200, ["vegetarian", "vegan", "gluten-free"]),
        _deal("latte-1", "leaf-kitchen", ["coffee"], 300, 500, ["vegetarian", "vegan"]),
        _deal("taco-1", "taco-window", ["tacos"], 900, 1300, []),
        _deal("cone-1", "creamery", ["dessert"], 300, 500, ["vegetarian"]),
        _deal("bbq-1", "smokehouse", ["bbq"], 1400, 1800, []),
        _deal("sushi-1", "maki-stop", ["sushi"], 1200, 1500, ["gluten-free"])
    ];
}


def _ids(feed: list[Ranked]) -> list[str] {
    return [r.candidate.offer_id for r in feed];
}


test "cuisine text maps to categories" {
    assert categories_for("Noodles and dumplings") == ["noodles"];
    assert categories_for("Pizza by the slice") == ["pizza"];
    assert categories_for("Plant-based bowls") == ["bowls", "salads"];
    assert categories_for("Cafe", "Oat Latte") == ["coffee"];
    assert categories_for("Mystery food") == [];
    assert categories_for("Subway station snacks") == [];
}


test "price ranges cover every price exactly once" {
    assert price_range_of(0) == "under5" and price_range_of(499) == "under5";
    assert price_range_of(500) == "5to8" and price_range_of(800) == "5to8";
    assert price_range_of(801) == "8to12" and price_range_of(1200) == "8to12";
    assert price_range_of(1201) == "12plus" and price_range_of(9900) == "12plus";
    assert price_range_label("5to8") == "$5 to $8" and price_range_label("nope") == "";
}


test "choices are cleaned to known values" {
    assert clean_choices(["Pizza", " noodles ", "pizza", "lasers"], CATEGORIES) == ["noodles", "pizza"];
    assert clean_choices(["VEGAN", "keto"], DIETS) == ["vegan"];
    assert clean_choices([], DIETS) == [];
}


test "place labels say whether everything or only some items qualify" {
    assert place_labels([["vegetarian", "vegan"], ["vegetarian"]]) == ["Vegetarian", "Vegan options"];
    assert place_labels([["halal"], []]) == ["Halal options"];
    assert place_labels([[], []]) == [];
    assert place_labels([]) == [];
}


test "learned interest weighs the action and fades with age" {
    fresh = Taste(history=[Signal(category="pizza", action="redeem", age_days=0.0)]);
    old = Taste(history=[Signal(category="pizza", action="redeem", age_days=14.0)]);
    claim = Taste(history=[Signal(category="pizza", action="claim", age_days=0.0)]);
    assert affinity(fresh, "pizza") == 3.0;
    assert affinity(old, "pizza") == 1.5;
    assert affinity(claim, "pizza") == 2.0;
    assert affinity(fresh, "tacos") == 0.0;
    many = Taste(history=[Signal(category="pizza", action="redeem", age_days=0.0) for i in range(10)]);
    assert affinity(many, "pizza") == 3.0;
}


test "preferences reorder but never hide a deal" {
    menu = _menu();
    for taste in [
        Taste(),
        Taste(categories=["noodles"]),
        Taste(categories=["noodles", "pizza"], diets=["vegan"], price_range="under5"),
        Taste(diets=["halal"]),
        Taste(favorites=["smokehouse"]),
        Taste(history=[Signal(category="tacos", action="redeem", age_days=1.0)])
    ] {
        feed = build_feed(_menu(), taste, "viewer");
        assert sorted(_ids(feed)) == sorted([c.offer_id for c in menu]);
        assert len(set(_ids(feed))) == len(menu);
    }
}


test "stated categories lead and the fourth slot is something different" {
    feed = build_feed(_menu(), Taste(categories=["noodles", "pizza", "tacos", "sushi"]), "viewer");
    assert [r.slot for r in feed[:4]] == ["match", "match", "match", "explore"];
    assert sorted(_ids(feed[:3])) == ["noodle-1", "pizza-1", "taco-1"] or "sushi-1" in _ids(feed[:3]);
    assert all([r.candidate.categories[0] in ["noodles", "pizza", "tacos", "sushi"] for r in feed[:3]]);
    assert feed[3].candidate.categories[0] not in ["noodles", "pizza", "tacos", "sushi"];
    assert feed[3].reasons[0] == "Something different";
    assert "You like" in feed[0].reasons[0];
}


test "favorites are pinned first, two places at most" {
    taste = Taste(categories=["noodles"], favorites=["smokehouse", "maki-stop", "creamery"]);
    feed = build_feed(_menu(), taste, "viewer");
    assert [r.slot for r in feed[:2]] == ["favorite", "favorite"];
    assert all([r.candidate.place in taste.favorites for r in feed[:2]]);
    assert "A favorite of yours" in feed[0].reasons;
    assert len([r for r in feed if r.slot == "favorite"]) == 2;
}


test "dietary needs lower a deal and label it, without removing it" {
    feed = build_feed(_menu(), Taste(categories=["noodles", "bbq", "tacos"], diets=["vegetarian"]), "viewer");
    assert feed[0].candidate.offer_id == "noodle-1";
    assert "Vegetarian" in feed[0].reasons;
    bbq = [r for r in feed if r.candidate.offer_id == "bbq-1"][0];
    assert not bbq.matched and "Not marked vegetarian" in bbq.reasons;
    assert "bbq-1" in _ids(feed);    fan = build_feed(_menu(), Taste(categories=["noodles"], diets=["vegetarian"], favorites=["smokehouse"]), "viewer");
    assert fan[0].slot == "favorite" and fan[0].candidate.offer_id == "bbq-1";
    assert "Not marked vegetarian" in fan[0].reasons;
    assert all([not [d for d in ["vegetarian"] if d not in r.candidate.dietary] for r in fan if r.slot == "match"]);
}


test "price range favors deals inside it" {
    taste = Taste(categories=["coffee", "dessert", "bbq", "sushi"], price_range="under5");
    feed = build_feed(_menu(), taste, "viewer");
    assert sorted(_ids(feed[:2])) == ["cone-1", "latte-1"];
    assert "In your price range" in feed[0].reasons;
    pricey = [r for r in feed if r.candidate.offer_id == "bbq-1"][0];
    assert pricey.score < feed[0].score;
}


test "history alone personalizes the feed" {
    taste = Taste(history=[
        Signal(category="tacos", action="redeem", age_days=2.0),
        Signal(category="tacos", action="claim", age_days=5.0)
    ]);
    feed = build_feed(_menu(), taste, "viewer");
    assert feed[0].candidate.offer_id == "taco-1";
    assert feed[0].reasons[0] == "Like places you have tried";
}


test "with nothing known, equal deals take turns between viewers" {
    same = [_deal(f"deal-{i}", f"place-{i}", ["pizza"], 700, 1000) for i in range(12)];
    firsts = set([build_feed([_deal(c.offer_id, c.place, c.categories, 700, 1000) for c in same], Taste(), f"viewer-{v}")[0].candidate.offer_id for v in range(30)]);
    assert len(firsts) >= 6, firsts;
    again = build_feed([_deal(c.offer_id, c.place, c.categories, 700, 1000) for c in same], Taste(), "viewer-1");
    repeat = build_feed([_deal(c.offer_id, c.place, c.categories, 700, 1000) for c in same], Taste(), "viewer-1");
    assert _ids(again) == _ids(repeat);
}


test "urgent deals say so" {
    soon = score(_deal("a", "p", ["pizza"], hours=1.0), Taste());
    few = score(_deal("b", "p", ["pizza"], remaining=2), Taste());
    calm = score(_deal("c", "p", ["pizza"]), Taste());
    assert "Ending soon" in soon.reasons and "Almost gone" in few.reasons;
    assert calm.reasons == [] and soon.score > calm.score;
}
