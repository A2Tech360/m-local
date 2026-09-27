"""Sandbox for the For you ranking: invented companies, invented students.

Generates random fictional companies and students from a seed, builds every
student's feed, and measures whether the ranking keeps its promises. Nothing
here touches the graph or the network. Run a report with:

    jac run services/taste_sandbox.jac
"""

import random;
import from services.taste {
    CATEGORIES,
    DIETS,
    PRICE_RANGES,
    Signal,
    Taste,
    Candidate,
    Ranked,
    build_feed,
    has_preferences,
    price_range_of
}


glob NAME_FIRST: list[str] = [
    "Maize", "Arbor", "Diag", "Huron", "Kerry", "Copper", "Velvet", "Tinder", "Paper",
    "Blue", "Golden", "Fig", "Cedar", "Lantern", "Atlas", "Juniper", "Harbor", "Ember"
];

glob NAME_LAST: dict[str, list[str]] = {
    "noodles": ["Noodle Lab", "Ramen Room"],
    "pizza": ["Dough Co.", "Slice House"],
    "bowls": ["Leaf Kitchen", "Grain Bowl"],
    "burgers": ["Burger Yard", "Smash Shack"],
    "tacos": ["Taqueria", "Taco Window"],
    "sandwiches": ["Deli", "Sandwich Works"],
    "breakfast": ["Diner", "Brunch Club"],
    "sushi": ["Sushi Bar", "Maki Stop"],
    "curry": ["Curry House", "Spice Bowl"],
    "salads": ["Greens", "Salad Shop"],
    "bbq": ["Smokehouse", "BBQ Pit"],
    "coffee": ["Coffee", "Espresso Bar"],
    "dessert": ["Creamery", "Cookie Bar"],
    "bakery": ["Bakery", "Crumb Shop"]
};


obj Company {
    has slug: str,
        name: str,
        category: str,
        dietary: list[str] = [],
        offers: list[Candidate] = [];
}

obj Student {
    has name: str,
        kind: str,
        taste: Taste = Taste();
}

obj SandboxReport {
    has companies: int = 0,
        offers: int = 0,
        students: int = 0,
        feeds_complete: int = 0,
        feeds_without_duplicates: int = 0,
        students_with_preferences: int = 0,
        match_mean_rank: float = 0.0,
        other_mean_rank: float = 0.0,
        top3_match_share: float = 0.0,
        explore_in_top8: float = 0.0,
        diet_safe_top3_share: float = 0.0,
        in_budget_top5_share: float = 0.0,
        in_budget_overall_share: float = 0.0,
        companies_seen_in_top5: int = 0,
        most_exposed_share: float = 0.0,
        favorites_in_top5_share: float = 0.0;
}


"""Random fictional companies, each with one to three live deals."""
def make_companies(count: int, seed: int) -> list[Company] {
    rng = random.Random(seed);
    out: list[Company] = [];
    for i in range(count) {
        category = rng.choice(CATEGORIES);
        name = rng.choice(NAME_FIRST) + " " + rng.choice(NAME_LAST[category]) + " (Demo)";
        dietary = [d for d in DIETS if rng.random() < 0.3];
        if "vegan" in dietary and "vegetarian" not in dietary {
            dietary = ["vegetarian"] + dietary;
        }
        company = Company(slug=f"company-{i}", name=name, category=category, dietary=dietary);
        for j in range(rng.randint(1, 3)) {
            price = rng.choice([300, 400, 500, 600, 700, 800, 900, 1000, 1200, 1400, 1600]);
            regular = price + rng.choice([100, 200, 300, 400, 500]);
            company.offers.append(Candidate(
                offer_id=f"offer-{i}-{j}",
                place=company.slug,
                title=f"{category.capitalize()} deal {j + 1}",
                categories=[category],
                dietary=[d for d in dietary if rng.random() < 0.9],
                price_cents=price,
                regular_cents=regular,
                remaining=rng.randint(1, 30),
                ends_in_hours=round(rng.uniform(0.5, 10.0), 1),
                rotation=rng.randint(0, 1000000)
            ));
        }
        out.append(company);
    }
    return out;
}


"""Random students of four kinds: no preferences, stated only, stated with a
history of claims, and history only."""
def make_students(count: int, companies: list[Company], seed: int) -> list[Student] {
    rng = random.Random(seed + 7919);
    kinds = ["blank", "stated", "stated+history", "history"];
    range_keys = [str(r[0]) for r in PRICE_RANGES];
    out: list[Student] = [];
    for i in range(count) {
        kind = kinds[i % len(kinds)];
        taste = Taste();
        if kind in ["stated", "stated+history"] {
            taste.categories = [c for c in CATEGORIES if c in rng.sample(CATEGORIES, rng.randint(1, 3))];
            taste.diets = [d for d in DIETS if rng.random() < 0.25];
            taste.price_range = rng.choice(range_keys + [""]);
            taste.favorites = [c.slug for c in rng.sample(companies, min(2, len(companies))) if rng.random() < 0.6];
        }
        if kind in ["history", "stated+history"] {
            liked = rng.sample(CATEGORIES, 2);
            for _ in range(rng.randint(3, 8)) {
                taste.history.append(Signal(
                    category=rng.choice(liked),
                    action=rng.choice(["claim", "redeem", "redeem", "favorite"]),
                    age_days=round(rng.uniform(0.0, 40.0), 1)
                ));
            }
        }
        out.append(Student(name=f"student-{i}", kind=kind, taste=taste));
    }
    return out;
}


def all_offers(companies: list[Company]) -> list[Candidate] {
    out: list[Candidate] = [];
    for c in companies {
        out.extend(c.offers);
    }
    return out;
}


def _share(part: int, whole: int) -> float {
    return round(part / whole, 3) if whole else 0.0;
}


"""Build every student's feed and measure the promises."""
def run_sandbox(company_count: int = 60, student_count: int = 200, seed: int = 442) -> SandboxReport {
    companies = make_companies(company_count, seed);
    students = make_students(student_count, companies, seed);
    offers = all_offers(companies);
    wanted_ids = sorted([o.offer_id for o in offers]);
    tally = SandboxReport(companies=len(companies), offers=len(offers), students=len(students));
    match_ranks: list[int] = [];
    other_ranks: list[int] = [];
    top3_match = 0;
    top3_total = 0;
    explore_top8 = 0;
    explore_possible = 0;
    diet_safe = 0;
    diet_total = 0;
    budget_hit = 0;
    budget_total = 0;
    budget_base_hit = 0;
    budget_base_total = 0;
    fav_hit = 0;
    fav_total = 0;
    top5_places: dict[str, int] = {};
    for s in students {
        feed = build_feed(offers, s.taste, s.name);
        ids = [r.candidate.offer_id for r in feed];
        if sorted(ids) == wanted_ids {
            tally.feeds_complete += 1;
        }
        if len(set(ids)) == len(ids) {
            tally.feeds_without_duplicates += 1;
        }
        for r in feed[:5] {
            top5_places[r.candidate.place] = top5_places.get(r.candidate.place, 0) + 1;
        }
        if not has_preferences(s.taste) {
            continue;
        }
        tally.students_with_preferences += 1;
        any_match = any([r.matched for r in feed]);
        for (i, r) in enumerate(feed) {
            if r.matched {
                match_ranks.append(i + 1);
            } else {
                other_ranks.append(i + 1);
            }
        }
        if any_match {
            top3_total += min(3, len([r for r in feed if r.matched or r.slot == "favorite"]));
            top3_match += len([r for r in feed[:3] if r.matched or r.slot == "favorite"]);
            if any([not r.matched for r in feed]) {
                explore_possible += 1;
                if len([r for r in feed[:8] if r.slot == "explore"]) >= 2 {
                    explore_top8 += 1;
                }
            }
        }
        if s.taste.diets and any_match {
            chosen = [r for r in feed[:3] if r.slot == "match"];
            diet_total += len(chosen);
            diet_safe += len([r for r in chosen if not [d for d in s.taste.diets if d not in r.candidate.dietary]]);
        }
        if s.taste.price_range and any_match {
            matched_top = [r for r in feed[:5] if r.slot == "match"];
            budget_total += len(matched_top);
            budget_hit += len([r for r in matched_top if price_range_of(r.candidate.price_cents) == s.taste.price_range]);
            matched_all = [r for r in feed if r.matched];
            budget_base_total += len(matched_all);
            budget_base_hit += len([r for r in matched_all if price_range_of(r.candidate.price_cents) == s.taste.price_range]);
        }
        if s.taste.favorites {
            fav_total += 1;
            if any([r.candidate.place in s.taste.favorites for r in feed[:5]]) {
                fav_hit += 1;
            }
        }
    }
    tally.match_mean_rank = round(sum(match_ranks) / len(match_ranks), 1) if match_ranks else 0.0;
    tally.other_mean_rank = round(sum(other_ranks) / len(other_ranks), 1) if other_ranks else 0.0;
    tally.top3_match_share = _share(top3_match, top3_total);
    tally.explore_in_top8 = _share(explore_top8, explore_possible);
    tally.diet_safe_top3_share = _share(diet_safe, diet_total);
    tally.in_budget_top5_share = _share(budget_hit, budget_total);
    tally.in_budget_overall_share = _share(budget_base_hit, budget_base_total);
    tally.favorites_in_top5_share = _share(fav_hit, fav_total);
    tally.companies_seen_in_top5 = len(top5_places);
    tally.most_exposed_share = _share(max(list(top5_places.values()) + [0]), len(students) * 5);
    return tally;
}


def print_report(r: SandboxReport) -> None {
    print(f"Sandbox: {r.companies} companies, {r.offers} deals, {r.students} students");
    print(f"  Every deal present in the feed       {r.feeds_complete}/{r.students} students");
    print(f"  No deal shown twice                  {r.feeds_without_duplicates}/{r.students} students");
    print(f"  Students with preferences or history {r.students_with_preferences}");
    print(f"  Average position of matching deals   {r.match_mean_rank}");
    print(f"  Average position of other deals      {r.other_mean_rank}");
    print(f"  Top 3 slots that are a match or favorite  {round(r.top3_match_share * 100)}%");
    print(f"  Feeds with 2 'something different' in top 8  {round(r.explore_in_top8 * 100)}%");
    print(f"  Matched top-3 deals that fit the diet {round(r.diet_safe_top3_share * 100)}%");
    print(f"  In the price range: top 5 vs all matches  {round(r.in_budget_top5_share * 100)}% vs {round(r.in_budget_overall_share * 100)}%");
    print(f"  Favorites appearing in the top 5     {round(r.favorites_in_top5_share * 100)}%");
    print(f"  Companies seen in someone's top 5    {r.companies_seen_in_top5}/{r.companies}");
    print(f"  Largest share of top-5 slots held by one company  {round(r.most_exposed_share * 100, 1)}%");
}


with entry {
    print_report(run_sandbox());
}
