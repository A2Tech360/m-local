"""Independent analytics calculations, with fixed Ann Arbor local times."""

import json
import unittest
from datetime import datetime
from zoneinfo import ZoneInfo

from services.analytics_support import build_insights


ZONE = ZoneInfo("America/Detroit")


def stamp(value):
    return datetime.fromisoformat(value).replace(tzinfo=ZONE).timestamp()


def claim(identity="private-claim", actor="private-person", claimed="2026-03-08T11:00", **overrides):
    result = dict(
        claim_id=identity, actor_id=actor, offer_id="offer-1", offer_title="Original lunch",
        is_demo=False, claimed_ts=stamp(claimed), expires_ts=stamp(claimed) + 1200,
        redeemed_ts=stamp(claimed) + 60, cancelled_ts=0, status="redeemed",
        price_cents=500, regular_price_cents=800,
    )
    result.update(overrides)
    return result


def summarize(records, now="2026-03-08T12:00", days=7, is_demo=False):
    return build_insights(records, "Fixture business", is_demo, days, stamp(now))


class AnalyticsTests(unittest.TestCase):
    def test_all_history_and_duplicates_count_once_and_never_export_people(self):
        records = [claim(str(i), f"private-person-{i}") for i in range(41)]
        view = summarize(records + [records[0]])
        self.assertEqual(view["totals"]["claims"], 41)
        self.assertEqual(view["totals"]["redemptions"], 41)
        self.assertEqual(view["totals"]["value_cents"], 20500)
        self.assertEqual(view["totals"]["savings_cents"], 12300)
        self.assertEqual(view["totals"]["savings_known"], 41)
        self.assertEqual(view["totals"]["unique_customers"], 41)
        rendered = json.dumps(view)
        self.assertNotIn("private-person", rendered)
        self.assertNotIn("claim_id", rendered)
        self.assertNotIn("actor_id", rendered)

    def test_carry_in_redemptions_are_separate_from_claim_cohort(self):
        row = claim(claimed="2026-03-01T23:55", redeemed_ts=stamp("2026-03-02T00:01"))
        view = summarize([row])
        self.assertEqual(view["start_date"], "2026-03-02")
        self.assertEqual(view["totals"]["redemptions"], 1)
        self.assertEqual(view["totals"]["claims"], 0)
        self.assertEqual(view["totals"]["cohort_redeemed"], 0)
        self.assertEqual(view["frames"][1]["daily"]["value_cents"], 500)

    def test_returning_accounts_require_distinct_local_dates_and_prior_history(self):
        rows = [claim("old", claimed="2026-02-28T12:00"),
                claim("same-day-1", actor="same", claimed="2026-03-02T14:00"),
                claim("same-day-2", actor="same", claimed="2026-03-02T15:00"),
                claim("new", claimed="2026-03-03T14:00"),
                claim("later", actor="same", claimed="2026-03-04T14:00")]
        view = summarize(rows)
        self.assertEqual(view["frames"][1]["totals"]["returning_customers"], 0)
        self.assertEqual(view["frames"][2]["totals"]["returning_customers"], 1)
        self.assertEqual(view["totals"]["returning_customers"], 2)
        self.assertEqual(view["totals"]["unique_customers"], 2)

    def test_local_midnights_spring_dst_and_final_as_of(self):
        rows = [claim("before", claimed="2026-03-01T23:59"),
                claim("midnight", claimed="2026-03-02T00:00"),
                claim("today", claimed="2026-03-08T00:00"),
                claim("future", claimed="2026-03-08T13:00")]
        view = summarize(rows)
        self.assertEqual(len(view["frames"]), 8)
        self.assertEqual(view["frames"][0]["date"], "2026-03-01")
        self.assertTrue(all(value == 0 for value in view["frames"][0]["totals"].values()))
        self.assertEqual(view["frames"][1]["daily"]["claims"], 1)
        self.assertEqual(view["frames"][-1]["daily"]["claims"], 1)
        self.assertEqual(view["totals"]["claims"], 2)
        self.assertEqual(view["totals"]["redemptions"], 3)  # one carried over midnight

    def test_fall_dst_month_boundary_and_replay_no_future_money_or_title(self):
        rows = [claim("first", claimed="2026-10-31T23:58", redeemed_ts=stamp("2026-11-01T00:01")),
                claim("second", claimed="2026-11-02T11:00", offer_title="Future renamed offer", price_cents=700)]
        view = summarize(rows, now="2026-11-02T12:00")
        previous = view["frames"][-2]
        self.assertEqual(previous["date"], "2026-11-01")
        self.assertEqual(previous["totals"]["claims"], 1)
        self.assertEqual(previous["totals"]["value_cents"], 500)
        self.assertEqual(previous["offers"][0]["title"], "Original lunch")
        self.assertEqual(view["offers"][0]["title"], "Future renamed offer")
        self.assertEqual(view["totals"]["value_cents"], 1200)

    def test_cancellation_timing_expiry_pending_and_legacy_unknown(self):
        rows = [claim("cancel", claimed="2026-03-07T23:55", redeemed_ts=0,
                      status="cancelled", cancelled_ts=stamp("2026-03-08T00:01")),
                claim("legacy", status="cancelled", redeemed_ts=0),
                claim("expiry", claimed="2026-03-07T10:00", status="claimed", redeemed_ts=0),
                claim("pending", claimed="2026-03-08T11:55", status="claimed", redeemed_ts=0)]
        view = summarize(rows)
        yesterday = view["frames"][-2]["totals"]
        self.assertEqual(yesterday["pending"], 1)
        self.assertEqual(yesterday["expired"], 1)
        self.assertEqual(yesterday["cancelled"], 0)
        self.assertEqual(view["totals"]["cancelled"], 1)
        self.assertEqual(view["totals"]["pending"], 1)
        self.assertEqual(view["totals"]["expired"], 1)
        self.assertEqual(view["totals"]["unknown_outcomes"], 1)
        self.assertTrue(any("cancellation" in item for item in view["warnings"]))
        outcomes = sum(view["totals"][key] for key in ("cohort_redeemed", "cancelled", "expired", "pending", "unknown_outcomes"))
        self.assertEqual(outcomes, view["totals"]["claims"])

    def test_missing_timestamps_money_and_accounts_are_not_invented(self):
        rows = [claim("bad-date", claimed_ts=0),
                claim("bad-money", actor="", price_cents=-1, regular_price_cents=-1),
                claim("missing-redemption", redeemed_ts=0),
                claim("bad-baseline", regular_price_cents=100)]
        view = summarize(rows)
        self.assertEqual(view["totals"]["claims"], 3)
        self.assertEqual(view["totals"]["redemptions"], 3)
        self.assertEqual(view["totals"]["value_cents"], 1000)
        self.assertEqual(view["totals"]["savings_cents"], 300)
        self.assertEqual(view["totals"]["savings_known"], 1)
        self.assertEqual(view["totals"]["unknown_outcomes"], 1)
        self.assertEqual(view["totals"]["unique_customers"], 1)
        self.assertGreaterEqual(len(view["warnings"]), 4)

    def test_demo_offers_excluded_from_real_business_and_empty_period_valid(self):
        rows = [claim("real"), claim("demo", is_demo=True)]
        self.assertEqual(summarize(rows)["totals"]["redemptions"], 1)
        self.assertEqual(summarize(rows, is_demo=True)["totals"]["redemptions"], 2)
        empty = summarize([], days=365)
        self.assertEqual(len(empty["frames"]), 366)
        self.assertEqual(empty["coverage_start_date"], "")
        self.assertFalse(empty["engagement_available"])
        self.assertEqual(empty["offers"], [])
        self.assertTrue(all(value == 0 for value in empty["totals"].values()))

    def test_unsupported_period_rejected(self):
        with self.assertRaises(ValueError):
            summarize([], days=8)


if __name__ == "__main__":
    unittest.main()
