"""Merchant-owned, aggregate-only analytics over canonical graph claims.

There is no merchant-ID input and no alternate simulation data source. Traversal
is separate from the portal's 30-item display limit. Private claim records stay
inside this server boundary; only daily summaries leave it.
"""

import time;
import from services.models { Restaurant, Publishes, ClaimedAs }
import from services.session { _actor_id, _merchant_for_actor }
import from services.qr_catalog { _ensure_seed }
import from services.analytics_support { build_insights }


def _insights_for(r: Restaurant, days: int, now: float) -> dict[str, any] {
    records: list[dict[str, any]] = [];
    for o in [r ->:Publishes:->] {
        if o.is_demo and not r.is_demo { continue; }
        for c in [o ->:ClaimedAs:->] {
            records.append({
                "claim_id": jid(c), "actor_id": c.actor_id,
                "offer_id": jid(o), "offer_title": c.offer_title_snapshot,
                "is_demo": o.is_demo, "claimed_ts": c.claimed_ts,
                "expires_ts": c.expires_ts, "redeemed_ts": c.redeemed_ts,
                "cancelled_ts": c.cancelled_ts, "status": c.status,
                "price_cents": c.price_cents_snapshot,
                "regular_price_cents": c.regular_price_cents_snapshot,
                "offer_start_ts": o.start_ts, "offer_end_ts": o.end_ts
            });
        }
    }
    return build_insights(records, r.name, r.is_demo, days, now);
}


def:protect merchant_insights(days: int = 30) -> dict[str, any] {
    _ensure_seed();
    r = _merchant_for_actor(_actor_id());
    if r is None {
        return {"ok": False, "message": "This account does not own a restaurant."};
    }
    if days not in [7, 30, 90, 365] {
        return {"ok": False, "message": "Choose a 7, 30, 90, or 365 day period."};
    }
    return _insights_for(r, days, time.time());
}
