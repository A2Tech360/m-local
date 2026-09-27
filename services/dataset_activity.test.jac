"""Pure synthetic-history checks, with no graph/account writes."""
import from services.analytics_support { build_insights }

test "fixed anchor gives stable private records and independent business histories" {
    anchor = datetime(2026, 9, 27, 23, 59, tzinfo=ZoneInfo("America/Detroit")).timestamp();
    rows = activity_records("dataset-test-cafe", anchor);
    assert rows == activity_records("dataset-test-cafe", anchor);
    assert rows != activity_records("dataset-test-bakery", anchor);
    assert 100 < len(rows) < 1000;
    assert len({r["claim_id"] for r in rows}) == len(rows);
    assert not {r["actor_id"] for r in rows}.intersection({r["actor_id"] for r in activity_records("dataset-test-bakery", anchor)});
    rows[0]["price_cents"] = 1;
    assert activity_records("dataset-test-cafe", anchor)[0]["price_cents"] != 1;
}

test "thirty local days have varied bounded volume coherent outcomes and snapshots" {
    anchor = datetime(2026, 3, 10, 23, 59, tzinfo=ZoneInfo("America/Detroit")).timestamp();
    rows = activity_records("dataset-test-cafe", anchor);
    counts: dict[str, int] = {};
    previous = 0.0;
    for row in rows {
        claimed = row["claimed_ts"] as float;
        expires = row["expires_ts"] as float;
        assert previous <= claimed and claimed < expires and expires <= anchor;
        previous = claimed;
        day = datetime.fromtimestamp(claimed, ZoneInfo("America/Detroit")).date().isoformat();
        counts[day] = counts.get(day, 0) + 1;
        assert row["is_demo"] and row["actor_id"].startswith("dataset-actor-");
        assert 0 < row["price_cents"] <= row["regular_price_cents"];
        assert row["offer_title"] and row["offer_id"];
        if row["status"] == "redeemed" {
            assert claimed < row["redeemed_ts"] < expires and row["cancelled_ts"] == 0.0;
        } elif row["status"] == "cancelled" {
            assert claimed < row["cancelled_ts"] < expires and row["redeemed_ts"] == 0.0;
        } else { assert row["status"] == "expired" and row["redeemed_ts"] == 0.0 and row["cancelled_ts"] == 0.0; }
    }
    assert len(counts) == 30 and len(set(counts.values())) > 3;
    assert {r["status"] for r in rows} == {"redeemed", "cancelled", "expired"};
    view = build_insights(rows, "Cafe", True, 30, anchor);
    assert view["totals"]["claims"] == len(rows);
    assert view["totals"]["redemptions"] == len([r for r in rows if r["status"] == "redeemed"]);
    assert view["totals"]["value_cents"] == sum([r["price_cents"] for r in rows if r["status"] == "redeemed"]);
    assert view["totals"]["returning_customers"] > 0;
    assert view["totals"]["pending"] == 0 and view["totals"]["unknown_outcomes"] == 0;
    assert view["warnings"] == [];
    assert build_insights(rows, "Real business", False, 30, anchor)["totals"]["claims"] == 0;
}

test "early import anchor never invents future activity" {
    anchor = datetime(2026, 9, 27, 0, 1, tzinfo=ZoneInfo("America/Detroit")).timestamp();
    rows = activity_records("dataset-test-early", anchor);
    assert len(rows) > 0;
    assert all(r["expires_ts"] <= anchor for r in rows);
}
