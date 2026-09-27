"""Sandbox checks: the ranking keeps its promises on invented companies and
students. Run: jac test services/taste_sandbox.jac"""

test "generation is repeatable and clearly fictional" {
    a = make_companies(40, 7);
    b = make_companies(40, 7);
    c = make_companies(40, 8);
    assert [x.name for x in a] == [x.name for x in b];
    assert [x.name for x in a] != [x.name for x in c];
    assert all([x.name.endswith("(Demo)") for x in a]);
    assert all([len(x.offers) >= 1 and len(x.offers) <= 3 for x in a]);
    assert all([o.regular_cents > o.price_cents for x in a for o in x.offers]);
    students = make_students(40, a, 7);
    assert sorted(set([s.kind for s in students])) == ["blank", "history", "stated", "stated+history"];
}


test "promises hold across sizes and seeds" {
    for (companies, students, seed) in [(60, 200, 442), (25, 80, 1), (150, 120, 99), (8, 40, 5)] {
        r = run_sandbox(companies, students, seed);
        label = f"{companies} companies, seed {seed}";
        assert r.feeds_complete == r.students, label;
        assert r.feeds_without_duplicates == r.students, label;
        assert r.match_mean_rank < r.other_mean_rank, label;
        assert r.top3_match_share >= 0.9, (label, r.top3_match_share);
        assert r.explore_in_top8 >= 0.95, (label, r.explore_in_top8);
        assert r.favorites_in_top5_share >= 0.95, (label, r.favorites_in_top5_share);
        assert r.in_budget_top5_share > r.in_budget_overall_share, label;
        assert r.diet_safe_top3_share >= 0.75, (label, r.diet_safe_top3_share);
    }
}


test "exposure spreads across companies" {
    r = run_sandbox(60, 200, 442);
    assert r.companies_seen_in_top5 == 60;
    assert r.most_exposed_share <= 0.1, r.most_exposed_share;
    big = run_sandbox(150, 300, 3);
    assert big.companies_seen_in_top5 >= 140, big.companies_seen_in_top5;
    assert big.most_exposed_share <= 0.06, big.most_exposed_share;
}


test "a student with no preferences still gets every deal" {
    companies = make_companies(30, 11);
    offers = all_offers(companies);
    feed = build_feed(offers, Taste(), "guest");
    assert len(feed) == len(offers);
    assert all([r.slot == "more" for r in feed]);
}
