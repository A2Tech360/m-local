"""Server-rule checks. Run: jac clean --data --force && jac test services/promo.jac"""

import time;


def _offer_by_title(title: str) -> Offer {
    for r in [root-->[?:Restaurant]] {
        for o in [r ->:Publishes:->] {
            if o.title == title {
                return o;
            }
        }
    }
    raise Exception("missing " + title);
}


test "seed is persistent and idempotent" {
    _ensure_seed();
    n = len([root-->[?:Restaurant]]);
    seed_demo();
    assert n >= 3;
    assert len([root-->[?:Restaurant]]) == n;
    assert all([r.name.endswith("(Demo)") for r in [root-->[?:Restaurant]]]);
}


test "claim then merchant redeem, repeated redemption rejected" {
    _ensure_seed();
    o = _offer_by_title("$3 oat latte study break");
    now = time.time();
    res = _claim(jid(o), "check-student-1", now);
    assert res.ok, res.message;
    again = _claim(jid(o), "check-student-1", now);
    assert not again.ok;
    ok = _redeem("leaf-demo", res.code, now);
    assert ok.ok, ok.message;
    twice = _redeem("leaf-demo", res.code, now);
    assert not twice.ok and "already redeemed" in twice.message;
    after = _claim(jid(o), "check-student-1", now);
    assert not after.ok and "already redeemed" in after.message;
}


test "merchant isolation" {
    _ensure_seed();
    o = _offer_by_title("Harvest bowl for $8");
    now = time.time();
    res = _claim(jid(o), "check-student-2", now);
    assert res.ok;
    wrong = _redeem("noodle-demo", res.code, now);
    assert not wrong.ok;
    noodle = _merchant("noodle-demo") as Restaurant;
    denied = _save_offer(
        noodle, jid(o), "Hijack", "", "1", "2", "2026-01-01 10:00", "2026-01-01 12:00",
        "5", "Anyone", "None", "", "", now
    );
    assert not denied.ok;
    assert o.title == "Harvest bowl for $8";
    assert _merchant("") is None and _merchant("bogus") is None;
}


test "expired and not-started offers cannot be claimed" {
    _ensure_seed();
    o = _offer_by_title("Lunch noodle bowl for $7");
    later = o.end_ts + 60;
    res = _claim(jid(o), "check-student-3", later);
    assert not res.ok and "expired" in res.message;
    early = _claim(jid(o), "check-student-3", o.start_ts - 60);
    assert not early.ok and "not started" in early.message;
}


test "quantity limit and abandoned claims release availability" {
    _ensure_seed();
    o = _offer_by_title("Slice + drink for $5");
    now = time.time();
    start = _remaining(o, now);
    codes: list[str] = [];
    for i in range(start) {
        r = _claim(jid(o), f"qty-student-{i}", now);
        assert r.ok, r.message;
        codes.append(r.code);
    }
    assert _remaining(o, now) == 0;
    blocked = _claim(jid(o), "qty-student-extra", now);
    assert not blocked.ok and "sold out" in blocked.message;
    hold_end = now + CLAIM_HOLD_MINUTES * 60 + 5;
    if hold_end < o.end_ts {
        assert _remaining(o, hold_end) == start;
        late = _redeem("dough-demo", codes[0], hold_end);
        assert not late.ok and "expired" in late.message;
    }
}


test "paused offers are hidden and unclaimable" {
    _ensure_seed();
    o = _offer_by_title("Weekend cheese slice deal");
    assert o.status == "paused";
    res = _claim(jid(o), "check-student-4", time.time());
    assert not res.ok;
    titles = [v.title for v in list_offers()];
    assert "Weekend cheese slice deal" not in titles;
}


test "filters and match explanation" {
    _ensure_seed();
    vegan = list_offers("", "", "any", "vegan");
    assert len(vegan) >= 1;
    assert all(["vegan" in v.dietary for v in vegan]);
    cheap = list_offers("", "5", "any", "");
    assert all([v.price <= 5 for v in cheap]);
    o = _offer_by_title("Harvest bowl for $8");
    v = get_offer(jid(o), "", "10", "now", "vegan") as OfferView;
    assert v.fits;
    assert "Under your $10.00 budget" in v.reasons;
    assert "Vegan" in v.reasons;
}
