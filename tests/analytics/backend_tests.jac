"""Business analytics checks. Run in a disposable source copy and graph only."""

import os;
import json;
import time;
import from services.analytics { _insights_for, merchant_insights }
import from services.models { Restaurant, Offer, Redemption, Publishes, ClaimedAs }
import from services.promo { _claim, _redeem, _cancel, _portal }
import from services.session { _merchant_for_actor }


def business(slug: str = "analytics-fixture", is_demo: bool = False) -> Restaurant {
    r = Restaurant(slug=slug, name="Analytics fixture", is_demo=is_demo);
    root.shared ++> r;
    return r;
}


def offer_for(r: Restaurant, now: float) -> Offer {
    o = Offer(title="Original lunch", price_cents=500, regular_price_cents=800,
        price=5.0, regular_price=8.0, start_ts=now - 60, end_ts=now + 3600,
        created_ts=now - 60, quantity=50, qr_ready=True, is_demo=r.is_demo);
    r +>:Publishes():+> o;
    return o;
}


test "analytics includes all forty one canonical claims beyond portal limit" {
    now = 1772982000.0;
    r = business();
    o = offer_for(r, now);
    for index in range(41) {
        actor = "private-actor-" + str(index);
        accepted = _claim(jid(o), actor, now);
        assert accepted.ok;
        assert _claim(jid(o), actor, now + 1).claim_id == accepted.claim_id;
        assert _redeem(r, accepted.qr_payload, now + 2).ok;
        assert not _redeem(r, accepted.qr_payload, now + 3).ok;
    }
    assert len(_portal(r, now + 5).claims) == 30;
    result = _insights_for(r, 7, now + 5);
    totals = result["totals"];
    assert totals["claims"] == 41;
    assert totals["redemptions"] == 41;
    assert totals["cohort_redeemed"] == 41;
    assert totals["value_cents"] == 20500;
    assert totals["savings_cents"] == 12300;
    assert totals["unique_customers"] == 41;
    encoded = json.dumps(result);
    for private_field in ["private-actor", "qr_payload", "claim_id", "actor_id"] {
        assert private_field not in encoded;
    }
}


test "editing an offer and retrying redemption does not rewrite historical prices" {
    now = 1772982000.0;
    r = business();
    o = offer_for(r, now);
    accepted = _claim(jid(o), "buyer", now);
    o.title = "Edited public title";
    o.price_cents = 100;
    o.regular_price_cents = 10000;
    assert _redeem(r, accepted.qr_payload, now + 10).ok;
    result = _insights_for(r, 7, now + 20);
    assert result["totals"]["value_cents"] == 500;
    assert result["totals"]["savings_cents"] == 300;
    assert result["offers"][0]["title"] == "Original lunch";
    assert not _redeem(r, accepted.qr_payload, now + 21).ok;
    assert _insights_for(r, 7, now + 22)["totals"]["redemptions"] == 1;
}


test "cancelled claims use recorded time and legacy cancellations remain unknown" {
    now = 1772982000.0;
    r = business();
    o = offer_for(r, now);
    accepted = _claim(jid(o), "cancelling-buyer", now);
    assert accepted.ok;
    assert _cancel(jid(o), "cancelling-buyer", now + 10).ok;
    assert _insights_for(r, 7, now + 5)["totals"]["pending"] == 1;
    assert _insights_for(r, 7, now + 15)["totals"]["cancelled"] == 1;
    legacy = Redemption(actor_id="legacy-buyer", restaurant_slug=r.slug,
        claimed_ts=now, expires_ts=now + 20, status="cancelled");
    o +>:ClaimedAs():+> legacy;
    result = _insights_for(r, 7, now + 30);
    assert result["totals"]["unknown_outcomes"] == 1;
    assert result["totals"]["expired"] == 0;
}


test "merchant traversal isolates another business and real totals exclude demo offers" {
    now = 1772982000.0;
    real = business("real-business");
    other = business("other-business");
    real_offer = offer_for(real, now);
    demo_offer = offer_for(real, now);
    demo_offer.is_demo = True;
    other_offer = offer_for(other, now);
    for pair in [(real, real_offer), (real, demo_offer), (other, other_offer)] {
        accepted = _claim(jid(pair[1]), "buyer", now);
        assert _redeem(pair[0], accepted.qr_payload, now + 1).ok;
    }
    result = _insights_for(real, 7, now + 2);
    assert result["totals"]["redemptions"] == 1;
    assert len(result["offers"]) == 1;
    assert result["offers"][0]["id"] == jid(real_offer);
    real.is_demo = True;
    assert _insights_for(real, 7, now + 2)["totals"]["redemptions"] == 2;
}


test "unowned actor and empty identity receive no private analytics" {
    previous = os.environ.get("MLOCAL_MERCHANT_OWNERS", "");
    os.environ["MLOCAL_MERCHANT_OWNERS"] = "{}";
    try {
        r = business();
        _ = offer_for(r, time.time());
        assert _merchant_for_actor("") is None;
        assert _merchant_for_actor("unowned-person") is None;
        result = merchant_insights();
        assert not result["ok"];
        assert "totals" not in result and "business_name" not in result;
    } finally {
        os.environ["MLOCAL_MERCHANT_OWNERS"] = previous;
    }
}
