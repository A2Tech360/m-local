"""Server-rule checks. Run bash scripts/test.sh core in an isolated store."""

import time;
import from services.seed { seed_demo }


def _offer_by_title(title: str) -> Offer {
    for r in [root.shared -->[?:Restaurant]] {
        for o in [r ->:Publishes:->] {
            if o.title == title {
                return o;
            }
        }
    }
    raise Exception("missing " + title);
}


def _restaurant_by_slug(slug: str) -> Restaurant {
    for r in [root.shared -->[?:Restaurant]] {
        if r.slug == slug { return r; }
    }
    raise Exception("missing " + slug);
}


test "seed is persistent and idempotent" {
    _ensure_seed();
    n = len([root.shared -->[?:Restaurant]]);
    seed_demo();
    assert n >= 3;
    assert len([root.shared -->[?:Restaurant]]) == n;
    assert all([r.name.endswith("(Demo)") for r in [root.shared -->[?:Restaurant]]]);
}


test "claim then merchant redeem, repeated redemption rejected" {
    _ensure_seed();
    o = _offer_by_title("$3 oat latte study break");
    now = time.time();
    res = _claim(jid(o), "check-student-1", now);
    assert res.ok, res.message;
    again = _claim(jid(o), "check-student-1", now);
    assert again.ok and again.qr_payload == res.qr_payload and again.claim_id == res.claim_id;
    ok = _redeem(_restaurant_by_slug("arbor-leaf-kitchen"), res.qr_payload, now);
    assert ok.ok, ok.message;
    twice = _redeem(_restaurant_by_slug("arbor-leaf-kitchen"), res.qr_payload, now);
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
    wrong = _redeem(_restaurant_by_slug("maize-noodle-lab"), res.qr_payload, now);
    assert not wrong.ok;
    noodle = _restaurant_by_slug("maize-noodle-lab");
    denied = _save_offer(
        noodle, jid(o), "Hijack", "", "1", "2", "2026-01-01 10:00", "2026-01-01 12:00",
        "5", "Anyone", "None", "", "", now
    );
    assert not denied.ok;
    assert o.title == "Harvest bowl for $8";
    assert _merchant_for_actor("") is None;
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
        codes.append(r.qr_payload);
    }
    assert _remaining(o, now) == 0;
    blocked = _claim(jid(o), "qty-student-extra", now);
    assert not blocked.ok and "sold out" in blocked.message;
    hold_end = now + CLAIM_HOLD_MINUTES * 60 + 5;
    if hold_end < o.end_ts {
        assert _remaining(o, hold_end) == start;
        late = _redeem(_restaurant_by_slug("diag-dough-co"), codes[0], hold_end);
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
    vegan = list_offers("", "any", "vegan");
    assert len(vegan) >= 1;
    assert all(["vegan" in v.dietary for v in vegan]);
    cheap = list_offers("5", "any", "");
    assert all([v.price <= 5 for v in cheap]);
    o = _offer_by_title("Harvest bowl for $8");
    v = get_offer(jid(o), "10", "now", "vegan") as OfferView;
    assert v.fits;
    assert "Under your $10.00 budget" in v.reasons;
    assert "Vegan" in v.reasons;
}


test "claim snapshot survives offer edits pause and deadline equality" {
    _ensure_seed();
    r = _restaurant_by_slug("arbor-leaf-kitchen");
    now = time.time();
    o = Offer(qr_ready=True, title="Snapshot test", price=7.25, price_cents=725,
        start_ts=now - 60, end_ts=now + 1800, quantity=2,
        terms="Original terms", eligibility="Original student ID");
    r +>:Publishes():+> o;
    result = _claim(jid(o), "snapshot-student", now);
    assert result.ok;
    before = _preview(r, result.qr_payload, now);
    o.title = "Changed title";
    o.price_cents = 999;
    o.terms = "Changed terms";
    o.eligibility = "Changed eligibility";
    o.end_ts = now + 10;
    o.status = "paused";
    after = _preview(r, result.qr_payload, now + 20);
    assert after.ok and after.title_snapshot == "Snapshot test";
    assert after.price_cents == 725 and after.terms == "Original terms";
    assert after.eligibility == "Original student ID";
    assert after.expires_ts == before.expires_ts;
    exact = _redeem(r, result.qr_payload, before.expires_ts);
    assert not exact.ok and "expired" in exact.message;
}


test "cancellation is idempotent releases once and stale QR cannot redeem" {
    _ensure_seed();
    r = _restaurant_by_slug("arbor-leaf-kitchen");
    now = time.time();
    o = Offer(qr_ready=True, title="Cancellation test", price_cents=100,
        start_ts=now - 60, end_ts=now + 1800, quantity=1);
    r +>:Publishes():+> o;
    first = _claim(jid(o), "cancel-student", now);
    assert first.ok and _remaining(o, now) == 0;
    assert _cancel(jid(o), "cancel-student", now).ok;
    assert _cancel(jid(o), "cancel-student", now).ok;
    assert _remaining(o, now) == 1;
    assert not _preview(r, first.qr_payload, now).ok;
    assert not _redeem(r, first.qr_payload, now).ok;
    replacement = _claim(jid(o), "cancel-student", now);
    assert replacement.ok and replacement.qr_payload != first.qr_payload;
    assert _view(o, now, "cancel-student").my_qr_payload == replacement.qr_payload;
    assert _redeem(r, replacement.qr_payload, now).ok;
    assert not _cancel(jid(o), "cancel-student", now).ok;
}


test "preview is read only and own claim fields never cross actor boundary" {
    _ensure_seed();
    r = _restaurant_by_slug("arbor-leaf-kitchen");
    now = time.time();
    o = Offer(qr_ready=True, title="Private view test", price_cents=100,
        start_ts=now - 60, end_ts=now + 1800, quantity=2);
    r +>:Publishes():+> o;
    result = _claim(jid(o), "view-student", now);
    assert result.ok;
    assert _preview(r, result.qr_payload, now).ok;
    assert _preview(r, result.qr_payload, now).ok;
    mine = _view(o, now, "view-student");
    assert mine.my_qr_payload == result.qr_payload and mine.my_status == "claimed";
    assert _view(o, now, "other-student").my_qr_payload == "";
    assert _view(o, now).my_claim_id == "";
    c = _find_claim(r, result.qr_payload) as Redemption;
    assert c.status == "claimed" and c.redeemed_ts == 0;
    _ = _preview(r, result.qr_payload, c.expires_ts);
    assert c.status == "claimed";
    assert not _redeem(r, "https://example.com/claim", now).ok;
    assert not _redeem(r, result.qr_payload + "=", now).ok;
}


test "pure claim deadline and repr keep credential private" {
    c = Redemption(actor_id="private-actor", qr_payload="mlocal:v1:" + "A" * 43,
        expires_ts=1000.0);
    assert _claim_status(c, 999.0) == "claimed";
    assert _claim_status(c, 1000.0) == "expired";
    assert c.status == "claimed";
    assert "private-actor" not in repr(c);
    assert c.qr_payload not in repr(c);
    c.status = "cancelled";
    assert _claim_status(c, 1001.0) == "cancelled";
    c.status = "redeemed";
    assert _claim_status(c, 1001.0) == "redeemed";
}


test "legacy consumed stock is never silently reopened by QR migration" {
    o = Offer(title="Legacy test", quantity=5, price_cents=100);
    o +>:ClaimedAs():+> Redemption(student_id="old-name", code="OLDCOD", status="redeemed");
    assert not o.qr_ready;
    assert _remaining(Offer(title="Unreconciled old offer", quantity=5), 1000.0) == 0;
    assert _remaining(o, 1000.0) == 0;
    assert _state(o, 1000.0) != "active";
}


test "offer views carry the location's access context with the server clock" {
    _ensure_seed();
    now = time.time();
    noodle = _offer_by_title("Lunch noodle bowl for $7");
    v = _view(noodle, now);
    assert v.location_id != "";
    assert v.access_context.state in ["current", "needs_recheck"], v.access_context.state;
    assert len(v.access_context.notices) >= 1;
    assert all([n.is_demo for n in v.access_context.notices]);
    for n in v.access_context.notices {
        if n.state != "current" {
            assert n.entrance_instruction == "";
        }
    }
    leaf = _offer_by_title("Harvest bowl for $8");
    other = _view(leaf, now);
    assert other.access_context.state == "none" and other.access_context.notices == [];
    stale = _view(noodle, now + 10 * 86400.0);
    assert stale.access_context.state == "needs_recheck";
    assert all([n.entrance_instruction == "" for n in stale.access_context.notices]);
}
