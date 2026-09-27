"""Pure, private-input to aggregate-output business analytics.

The graph adapter is responsible for authorization. This module receives only
canonical claim snapshots, never simulation events or editable offer prices.
Calendar boundaries are Ann Arbor local midnights, including DST transitions.
"""

from __future__ import annotations

import math
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo


TIMEZONE = "America/Detroit"
ALLOWED_DAYS = frozenset((7, 30, 90, 365))
METRICS = (
    "claims", "redemptions", "unique_customers", "returning_customers",
    "value_cents", "savings_cents", "savings_known", "cohort_redeemed",
    "cancelled", "expired", "pending", "unknown_outcomes",
)


@dataclass(frozen=True)
class _Claim:
    identity: str
    actor: str
    offer: str
    title: str
    claimed: float
    redeemed: float
    outcome: str
    resolved: float
    price: int | None
    regular: int | None


def _timestamp(value: Any) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return 0.0
    if not math.isfinite(value) or value <= 0:
        return 0.0
    # Reject epochs outside datetime's useful range before later conversions.
    try:
        datetime.fromtimestamp(value, ZoneInfo(TIMEZONE))
    except (ValueError, OverflowError, OSError):
        return 0.0
    return float(value)


def _cents(value: Any) -> int | None:
    return value if type(value) is int and value >= 0 else None


def _blank() -> dict[str, int]:
    return dict.fromkeys(METRICS, 0)


def _local_date(timestamp: float, zone: ZoneInfo) -> date:
    return datetime.fromtimestamp(timestamp, zone).date()


def _occurred(timestamp: float, cutoff: float, now: float) -> bool:
    return timestamp > 0 and timestamp < cutoff and timestamp <= now


def _normalize(records: list[dict[str, Any]], is_demo: bool, now: float) -> tuple[list[_Claim], list[str]]:
    rows: list[_Claim] = []
    seen: set[str] = set()
    gaps: Counter[str] = Counter()
    for raw in records:
        if raw.get("is_demo", False) and not is_demo:
            continue
        identity = str(raw.get("claim_id", ""))
        if not identity or identity in seen:
            continue
        seen.add(identity)
        claimed = _timestamp(raw.get("claimed_ts"))
        redeemed = _timestamp(raw.get("redeemed_ts"))
        cancelled = _timestamp(raw.get("cancelled_ts"))
        expires = _timestamp(raw.get("expires_ts"))
        # Do not project uncommitted/future-dated activity into the current view.
        if claimed > now:
            continue
        if not claimed:
            gaps["claim timestamps"] += 1
        state = raw.get("status", "")
        outcome, resolved = "unknown_outcomes", 0.0
        if state == "redeemed":
            if redeemed and (not claimed or redeemed >= claimed):
                outcome, resolved = "cohort_redeemed", redeemed
            else:
                gaps["redemption timestamps"] += 1
                redeemed = 0.0
        elif state == "cancelled":
            redeemed = 0.0
            if cancelled and (not claimed or cancelled >= claimed):
                outcome, resolved = "cancelled", cancelled
            else:
                gaps["cancellation timestamps"] += 1
        elif state in ("claimed", "expired"):
            redeemed = 0.0
            if expires and (not claimed or expires >= claimed):
                outcome, resolved = "expired", expires
            else:
                gaps["expiry timestamps"] += 1
        else:
            redeemed = 0.0
            gaps["claim outcome evidence"] += 1
        price = _cents(raw.get("price_cents"))
        regular = _cents(raw.get("regular_price_cents"))
        actor = str(raw.get("actor_id", ""))
        if redeemed and redeemed <= now:
            if price is None:
                gaps["immutable claim prices"] += 1
            if regular is None or price is None or regular < price:
                gaps["regular-price snapshots"] += 1
            if not actor:
                gaps["authenticated account identifiers"] += 1
        rows.append(_Claim(identity, actor, str(raw.get("offer_id", "")),
                           str(raw.get("offer_title", "")) or "Untitled claimed offer",
                           claimed, redeemed, outcome, resolved, price, regular))
    warnings = [f"{count} recorded claim(s) have missing or invalid {kind}; affected metrics show only known evidence."
                for kind, count in sorted(gaps.items())]
    return rows, warnings


def build_insights(records: list[dict[str, Any]], business_name: str,
                   is_demo: bool, days: int, now: float) -> dict[str, Any]:
    """Build a chronological, aggregate-only response from authorized claims.

    Period claims form the conversion cohort; period redemptions include carry-in
    claims. Returning accounts have a redemption on an earlier local date,
    including dates before the selected period. Daily pending/unknown counts
    describe that day's claim cohort, not a possibly negative inventory delta.
    """
    if type(days) is not int or days not in ALLOWED_DAYS:
        raise ValueError("Choose a 7, 30, 90, or 365 day period.")
    if not _timestamp(now):
        raise ValueError("A valid server timestamp is required.")
    zone = ZoneInfo(TIMEZONE)  # Fail rather than silently apply the host timezone.
    end_date = _local_date(now, zone)
    start_date = end_date - timedelta(days=days - 1)
    start_ts = datetime.combine(start_date, time.min, zone).timestamp()
    rows, warnings = _normalize(records, is_demo, now)
    coverage = [ts for row in rows for ts in (row.claimed, row.redeemed) if 0 < ts <= now]
    first_redemption: dict[str, date] = {}
    for row in rows:
        if row.actor and 0 < row.redeemed <= now:
            redeemed_date = _local_date(row.redeemed, zone)
            first_redemption[row.actor] = min(first_redemption.get(row.actor, redeemed_date), redeemed_date)

    frames: list[dict[str, Any]] = [{
        "day": 0, "date": (start_date - timedelta(days=1)).isoformat(),
        "daily": _blank(), "totals": _blank(), "offers": [],
    }]
    cohort = [row for row in rows if start_ts <= row.claimed <= now]
    redemptions = sorted((row for row in rows if start_ts <= row.redeemed <= now),
                         key=lambda row: (row.redeemed, row.identity))
    cumulative = _blank()
    customers: set[str] = set()
    returners: set[str] = set()
    offer_totals: dict[str, dict[str, Any]] = {}
    redemption_index = 0
    for index in range(days):
        calendar_date = start_date + timedelta(days=index)
        day_start = datetime.combine(calendar_date, time.min, zone).timestamp()
        cutoff = datetime.combine(calendar_date + timedelta(days=1), time.min, zone).timestamp()
        daily = _blank()
        day_customers: set[str] = set()
        day_returners: set[str] = set()
        for key in ("claims", "cohort_redeemed", "cancelled", "expired", "pending", "unknown_outcomes"):
            cumulative[key] = 0
        for row in cohort:
            if not _occurred(row.claimed, cutoff, now):
                continue
            today_claim = row.claimed >= day_start
            cumulative["claims"] += 1
            daily["claims"] += int(today_claim)
            outcome = row.outcome if row.outcome == "unknown_outcomes" or _occurred(row.resolved, cutoff, now) else "pending"
            cumulative[outcome] += 1
            # Resolutions are daily events; unresolved counts describe today's cohort.
            if outcome in ("pending", "unknown_outcomes"):
                daily[outcome] += int(today_claim)
            elif row.resolved >= day_start:
                daily[outcome] += 1
        while redemption_index < len(redemptions):
            row = redemptions[redemption_index]
            if not _occurred(row.redeemed, cutoff, now):
                break
            redemption_index += 1
            daily["redemptions"] += 1
            daily["value_cents"] += row.price if row.price is not None else 0
            if row.price is not None and row.regular is not None and row.regular >= row.price:
                daily["savings_known"] += 1
                daily["savings_cents"] += row.regular - row.price
            if row.actor:
                customers.add(row.actor)
                day_customers.add(row.actor)
                if first_redemption[row.actor] < calendar_date:
                    returners.add(row.actor)
                    day_returners.add(row.actor)
            offer = offer_totals.setdefault(row.offer, {"id": row.offer, "title": row.title, "redemptions": 0, "value_cents": 0})
            offer["title"] = row.title
            offer["redemptions"] += 1
            offer["value_cents"] += row.price if row.price is not None else 0
        daily["unique_customers"] = len(day_customers)
        daily["returning_customers"] = len(day_returners)
        cumulative["unique_customers"] = len(customers)
        cumulative["returning_customers"] = len(returners)
        for key in ("redemptions", "value_cents", "savings_cents", "savings_known"):
            cumulative[key] += daily[key]
        offers = sorted((dict(item) for item in offer_totals.values()),
                        key=lambda item: (-item["redemptions"], -item["value_cents"], item["id"]))
        frames.append({"day": index + 1, "date": calendar_date.isoformat(),
                       "daily": daily, "totals": dict(cumulative), "offers": offers})
    return {
        "ok": True, "message": "", "business_name": business_name, "is_demo": is_demo,
        "period_days": days, "timezone": TIMEZONE, "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(), "as_of": now,
        "coverage_start_date": _local_date(min(coverage), zone).isoformat() if coverage else "",
        "warnings": warnings, "engagement_available": False, "frames": frames,
        "totals": frames[-1]["totals"], "offers": frames[-1]["offers"],
    }
