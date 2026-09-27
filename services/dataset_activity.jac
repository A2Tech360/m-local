"""Deterministic private fixture records for a fixed catalog import anchor.

No graph, account, email, credential, or inventory mutation occurs here. Callers
must restrict this source to dataset businesses and keep is_demo provenance
when passing the records to build_insights. Persist the anchor once; do not use
the current clock on each read, which would rewrite the historical fixture.
"""
import hashlib;
import math;
import from datetime { datetime, timedelta }
import from zoneinfo { ZoneInfo }

def activity_records(slug: str, anchor: float) -> list[dict[str, any]] {
    if not slug.strip() or len(slug) > 256 or not math.isfinite(anchor) or anchor < 2678400.0 {
        raise ValueError("A business slug and valid fixed import timestamp are required.");
    }
    zone = ZoneInfo("America/Detroit");
    end = datetime.fromtimestamp(anchor, zone).date();
    identity = hashlib.sha256(slug.encode()).hexdigest()[:16];
    seed = int(identity[:8], 16);
    titles = ["Lunch special", "Afternoon special", "House favorite"];
    records: list[dict[str, any]] = [];
    for day_index in range(30) {
        day = end - timedelta(days=29 - day_index);
        stamp = day.isoformat();
        opening = datetime(day.year, day.month, day.day, 11, tzinfo=zone).timestamp();
        # Different weekday patterns, gentle growth, and bounded daily variation.
        volume = 8 + (seed + day_index * 7 + day_index * day_index) % 9 + day_index // 7;
        if day.weekday() in [4, 5] { volume += 5; }
        for slot in range(volume) {
            claimed = opening + slot * (8.0 * 3600.0 / volume) + float((seed + slot * 37) % 120);
            expires = claimed + 1800.0;
            if expires > anchor { continue; }
            variant = (day_index + slot + seed) % len(titles);
            outcome = (seed + day_index * 3 + slot * 7) % 10;
            status = "redeemed" if outcome < 7 else "cancelled" if outcome == 7 else "expired";
            resolved = claimed + float(120 + (slot * 83 + day_index * 29 + seed) % 1200);
            price = 500 + variant * 150;
            records.append({
                "claim_id": "dataset-claim-v1-" + identity + "-" + stamp + "-" + str(slot),
                "actor_id": "dataset-actor-" + identity + "-" + str((slot + day_index % 4) % 32),
                "offer_id": "dataset-offer-v1-" + identity + "-" + stamp + "-" + str(variant),
                "offer_title": titles[variant], "is_demo": True,
                "claimed_ts": claimed, "expires_ts": expires,
                "redeemed_ts": resolved if status == "redeemed" else 0.0,
                "cancelled_ts": resolved if status == "cancelled" else 0.0,
                "status": status, "price_cents": price, "regular_price_cents": price + 300
            });
        }
    }
    return records;
}
