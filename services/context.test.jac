"""Deterministic tests for source-labeled location access context."""

import from services.models { Restaurant, Location, HasLocation }
import from services.context_models { ContextNotice, ContextValidationError }
import from services.context { get_access_context }
import from services.importer { upsert_access_notice }


def _location(slug: str) -> Location {
    r = Restaurant(slug=slug, name=slug + " (Demo)", is_demo=True);
    root ++> r;
    r +>:HasLocation():+> Location(address="Fictional address", neighborhood="Demo");
    return [r ->:HasLocation:->][0];
}


def _record(slug: str, source: str = "test-source", external: str = "notice-1") -> dict {
    return {
        "source_id": source, "external_id": external, "location_slug": slug,
        "version": "1", "publisher": "Test publisher", "source_url": "",
        "checked_at": 100.0, "valid_from": 100.0, "valid_until": 200.0,
        "summary": "Simulated test notice", "is_demo": True,
        "entrance_instruction": "Confirmed only in this test"
    };
}


test "empty_context_is_unknown_not_clear_access" {
    loc = _location("empty-context");
    context = get_access_context(jid(loc), 150.0);
    assert context.state == "none";
    assert context.notices == [];
}


test "upsert_is_idempotent" {
    loc = _location("idempotent-context");
    record = _record("idempotent-context", "test-idempotent", "one");
    first = upsert_access_notice(record);
    second = upsert_access_notice(record);
    assert first == second;
    assert len([root-->[?:ContextNotice, source_id == "test-idempotent" and external_id == "one"]]) == 1;
    assert len(get_access_context(jid(loc), 150.0).notices) == 1;
}


test "new_version_updates_same_notice" {
    loc = _location("version-context");
    record = _record("version-context", "test-version", "one");
    first = upsert_access_notice(record);
    record["version"] = "2";
    record["summary"] = "Updated simulated notice";
    record["checked_at"] = 140.0;
    second = upsert_access_notice(record);
    context = get_access_context(jid(loc), 150.0);
    assert first == second;
    assert len(context.notices) == 1;
    assert context.notices[0].summary == "Updated simulated notice";
}


test "invalid_dates_rejected_without_mutation" {
    _location("invalid-date-context");
    record = _record("invalid-date-context", "test-invalid-date", "one");
    record["valid_until"] = 100.0;
    before = len([root-->[?:ContextNotice]]);
    try {
        upsert_access_notice(record);
        assert False, "invalid record must fail";
    } except ContextValidationError {
        pass;
    }
    assert len([root-->[?:ContextNotice]]) == before;
}


test "unknown_location_rejected" {
    record = _record("not-a-location", "test-unknown", "one");
    before = len([root-->[?:ContextNotice]]);
    try {
        upsert_access_notice(record);
        assert False, "unknown location must fail";
    } except ContextValidationError {
        pass;
    }
    assert len([root-->[?:ContextNotice]]) == before;
}


test "notice_boundary_and_freshness" {
    loc = _location("boundary-context");
    upsert_access_notice(_record("boundary-context", "test-boundary", "one"));
    assert get_access_context(jid(loc), 150.0).state == "current";
    assert get_access_context(jid(loc), 200.0).state == "needs_recheck";
    assert get_access_context(jid(loc), 99.0).state == "needs_recheck";
    stale = _record("boundary-context", "test-stale", "one");
    stale["checked_at"] = 150.0 - 86401.0;
    stale["valid_from"] = 0.0;
    stale["valid_until"] = 200.0;
    upsert_access_notice(stale);
    future = _record("boundary-context", "test-future", "one");
    future["checked_at"] = 151.0;
    upsert_access_notice(future);
    context = get_access_context(jid(loc), 150.0);
    assert any([v.state == "needs_recheck" and v.entrance_instruction == "" for v in context.notices]);
}


test "refresh_failure_preserves_old_timestamp" {
    loc = _location("failure-context");
    record = _record("failure-context", "test-failure", "one");
    notice_id = upsert_access_notice(record);
    failed_refresh = _record("failure-context", "test-failure", "one");
    failed_refresh["valid_until"] = 0.0;
    try {
        upsert_access_notice(failed_refresh);
        assert False, "failed source normalization must fail";
    } except ContextValidationError {
        pass;
    }
    context = get_access_context(jid(loc), 150.0);
    assert context.notices[0].id == notice_id;
    assert context.notices[0].checked_at == 100.0;
}


test "other_location_unchanged" {
    first = _location("first-context");
    second = _location("second-context");
    upsert_access_notice(_record("first-context", "test-first", "one"));
    before = get_access_context(jid(second), 150.0);
    updated = _record("first-context", "test-first", "one");
    updated["version"] = "2";
    updated["summary"] = "Changed only for first location";
    upsert_access_notice(updated);
    after = get_access_context(jid(second), 150.0);
    assert before.state == "none" and after.state == "none";
    assert get_access_context(jid(first), 150.0).notices[0].summary == "Changed only for first location";
}
