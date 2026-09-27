"""Simulated local activity for looking at business Insights.

Invented students claim and redeem sample offers at the three demo restaurants
over the past 30 days, through the app's own claim, cancel and redeem code.
Everything it adds is flagged demo. Only the isolated launcher in
scripts/insights-demo.sh imports this; it is never part of the hosted app.
"""

import os;
import random;
import time;
import from datetime { datetime, timedelta }
import from zoneinfo { ZoneInfo }
import from services.models { Restaurant, Offer, Publishes }
import from services.promo { _claim, _redeem, _cancel }


node ActivityLoaded {
    has claims: int = 0, redeemed: int = 0, cancelled: int = 0, expired: int = 0, students: int = 0;
    def __jac_access__ -> AccessLevel { return AccessLevel.READ; }
}


glob BLOCKS: list[list[any]] = [
    ["morning", 6.5, 10.8, 0.16],
    ["lunch", 11.2, 15.5, 0.40],
    ["dinner", 16.5, 20.8, 0.30],
    ["late", 21.2, 25.5, 0.14]
];

glob MENUS: dict[str, list[list[any]]] = {
    "morning": [["Morning coffee and bagel", 400, 650], ["Breakfast burrito", 500, 800]],
    "lunch": [["Student lunch bowl", 800, 1150], ["Lunch slice and drink", 600, 900]],
    "dinner": [["Dinner plate", 1100, 1500], ["Two-for-one dumplings", 900, 1400]],
    "late": [["Late-night slice", 400, 600], ["After-hours fries", 500, 750]]
};

glob POPULARITY: dict[str, dict[str, float]] = {
    "arbor-leaf-kitchen": {"morning": 1.6, "lunch": 1.2, "dinner": 0.6, "late": 0.2},
    "maize-noodle-lab": {"morning": 0.2, "lunch": 1.3, "dinner": 1.5, "late": 0.7},
    "diag-dough-co": {"morning": 0.3, "lunch": 1.0, "dinner": 1.1, "late": 1.8}
};


def setting(name: str, fallback: int) -> int {
    raw = os.environ.get(name, "").strip();
    return int(raw) if raw.isdigit() and int(raw) > 0 else fallback;
}


def ensure_local_activity {
    if [root.shared -->[?:ActivityLoaded]] {
        return;
    }
    started = time.time();
    rng = random.Random(setting("MLOCAL_ACTIVITY_SEED", 442));
    zone = ZoneInfo("America/Detroit");
    now = time.time();
    today = datetime.fromtimestamp(now, zone).replace(hour=0, minute=0, second=0, microsecond=0);
    days = 30;
    places = {r.slug: r for r in [root.shared -->[?:Restaurant]] if r.slug in POPULARITY};
    offers: dict[str, list[Offer]] = {};
    for (slug, r) in places.items() {
        for week in range(5) {
            opens = (today - timedelta(days=days - 1 - week * 7)).timestamp();
            closes = min(now + 3600, opens + 7 * 86400 + 6 * 3600);
            if opens >= now {
                continue;
            }
            for (block, menu) in MENUS.items() {
                pick = menu[(week + len(slug)) % len(menu)];
                o = Offer(
                    title=str(pick[0]), description="Fictional sample offer for looking at Insights.",
                    price=int(pick[1]) / 100, regular_price=int(pick[2]) / 100,
                    price_cents=int(pick[1]), regular_price_cents=int(pick[2]),
                    start_ts=opens, end_ts=closes, quantity=5000, is_demo=True, qr_ready=True,
                    eligibility="Students with a valid university ID",
                    terms="One per student. Fictional sample offer.", created_ts=opens
                );
                r +>:Publishes():+> o;
                offers.setdefault(slug + ":" + block + ":" + str(week), []).append(o);
            }
        }
    }
    students = setting("MLOCAL_ACTIVITY_STUDENTS", 250);
    tally = ActivityLoaded(students=students);
    for n in range(students) {
        actor = f"local-student-{n}";
        favorite = rng.choice(list(places.keys()));
        habit = rng.choice([b[0] for b in BLOCKS]);
        keen = rng.uniform(0.04, 0.22);
        for day in range(days) {
            date = today - timedelta(days=days - 1 - day);
            weekend = date.weekday() >= 5;
            if rng.random() > keen * (1.0 + 0.012 * day) * (1.25 if weekend else 1.0) {
                continue;
            }
            weights = [float(b[3]) * (2.2 if b[0] == habit else 1.0) * (1.6 if weekend and b[0] == "late" else 1.0) * (0.6 if weekend and b[0] == "morning" else 1.0) for b in BLOCKS];
            block = rng.choices(BLOCKS, weights=weights)[0];
            slug = favorite if rng.random() < 0.55 else rng.choices(list(places.keys()), weights=[POPULARITY[s][str(block[0])] for s in places.keys()])[0];
            moment = (date + timedelta(hours=rng.uniform(float(block[1]), float(block[2])))).timestamp();
            if moment >= now - 1800 {
                continue;
            }
            week = min(4, int(day / 7));
            found = offers.get(slug + ":" + str(block[0]) + ":" + str(week), []);
            if not found {
                continue;
            }
            claim = _claim(jid(found[0]), actor, moment);
            if not claim.ok or not claim.qr_payload {
                continue;
            }
            tally.claims += 1;
            outcome = rng.random();
            if outcome < 0.78 {
                if _redeem(places[slug], claim.qr_payload, moment + rng.uniform(120, 1080)).ok {
                    tally.redeemed += 1;
                }
            } elif outcome < 0.86 {
                if _cancel(jid(found[0]), actor, moment + rng.uniform(60, 600)).ok {
                    tally.cancelled += 1;
                }
            } else {
                tally.expired += 1;
            }
        }
    }
    root.shared ++> tally;
    print(f"Local activity ready: {tally.students} simulated students, {tally.claims} claims, {tally.redeemed} redeemed, {tally.cancelled} cancelled, {tally.expired} left to expire, {round(time.time() - started, 1)}s.");
}
