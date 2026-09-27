"""Deterministic tests for source-labeled location access context."""

import from services.models { Restaurant, Location, HasLocation }
import from services.context_models { ContextNotice, ContextValidationError, Affects }
import from services.importer { upsert_access_notice }


def _location(slug: str) -> Location {
    r = Restaurant(slug=slug, name=slug + " (Demo)", is_demo=True);
    root ++> r;
    r +>:HasLocation():+> Location(address="Fictional address", neighborhood="Demo");
    return [r ->:HasLocation:->][0];
}


def _record(slug: str, source: str = "test-source", external: str = "notice-1") -> dict[str, any] {
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
    assert len([root-->[?:ContextNotice, source_id == "test-idempotent", external_id == "one"]]) == 1;
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
    stale_id = upsert_access_notice(stale);
    future = _record("boundary-context", "test-future", "one");
    future["checked_at"] = 151.0;
    future_id = upsert_access_notice(future);
    context = get_access_context(jid(loc), 150.0);
    for notice_id in [stale_id, future_id] {
        view = [v for v in context.notices if v.id == notice_id][0];
        assert view.state == "needs_recheck" and view.entrance_instruction == "";
    }
    stale["checked_at"] = 150.0 - 86400.0;
    upsert_access_notice(stale);
    fresh = [v for v in get_access_context(jid(loc), 150.0).notices if v.id == stale_id][0];
    assert fresh.state == "current";
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

test "invalid_provenance_or_identity_cannot_partially_refresh_a_notice" {
    loc = _location("invalid-metadata-context");
    record = _record("invalid-metadata-context", "metadata", "one");
    notice_id = upsert_access_notice(record);
    for field in ["original_evidence", "normalized_evidence", "owner_actor_id", "merchant_key", "password", "role", "roles"] {
        bad = _record("invalid-metadata-context", "metadata", "one");
        bad["summary"] = "Must never replace the saved summary";
        bad["checked_at"] = 140.0;
        bad[field] = "untrusted-value";
        rejected = False;
        try { upsert_access_notice(bad); } except ContextValidationError { rejected = True; }
        assert rejected, field;
        context = get_access_context(jid(loc), 150.0);
        assert context.notices[0].id == notice_id;
        assert context.notices[0].summary == "Simulated test notice";
        assert context.notices[0].checked_at == 100.0;
    }
}

test "source_links_reject_non_web_urls_and_embedded_credentials" {
    loc = _location("unsafe-source-context");
    for url in ["javascript:alert(1)", "file:///tmp/source", "https://", "https://user:secret@example.test/notice"] {
        bad = _record("unsafe-source-context", "unsafe-url", url);
        bad["source_url"] = url;
        rejected = False;
        try { upsert_access_notice(bad); } except ContextValidationError { rejected = True; }
        assert rejected, "unsafe source link must not be stored";
    }
    assert get_access_context(jid(loc), 150.0).state == "none";
}

test "ambiguous_notice_edges_do_not_present_entrance_directions" {
    first = _location("ambiguous-first-context");
    second = _location("ambiguous-second-context");
    upsert_access_notice(_record("ambiguous-first-context", "ambiguous-notice", "one"));
    n = [root-->[?:ContextNotice, source_id == "ambiguous-notice"]][0];
    n +>:Affects():+> second;
    assert get_access_context(jid(first), 150.0).state == "none";
    assert get_access_context(jid(second), 150.0).state == "none";
    rejected = False;
    try { upsert_access_notice(_record("ambiguous-first-context", "ambiguous-notice", "one")); }
    except ContextValidationError { rejected = True; }
    assert rejected, "ambiguous existing association must fail closed";
}

test "real_notice_cannot_create_or_refresh_a_fictional_association" {
    loc = _location("fictional-source-context");
    record = _record("fictional-source-context", "source-boundary", "one");
    record["is_demo"] = False;
    record["source_url"] = "https://example.test/reviewed-notice";
    rejected = False;
    try { upsert_access_notice(record); } except ContextValidationError { rejected = True; }
    assert rejected, "real notice must not be created for a fictional restaurant";
    assert get_access_context(jid(loc), 150.0).state == "none";
    saved_id = upsert_access_notice(_record("fictional-source-context", "source-boundary", "one"));
    record["summary"] = "Must not replace the simulated notice";
    record["checked_at"] = 140.0;
    rejected = False;
    try { upsert_access_notice(record); } except ContextValidationError { rejected = True; }
    assert rejected, "refresh must not turn a fictional association into a real one";
    view = get_access_context(jid(loc), 150.0).notices[0];
    assert view.id == saved_id and view.is_demo;
    assert view.summary == "Simulated test notice" and view.checked_at == 100.0;
}

test "real_notice_can_target_a_non_demo_restaurant" {
    loc = _location("reviewed-source-context");
    restaurant = [root-->[?:Restaurant, slug == "reviewed-source-context"]][0];
    restaurant.is_demo = False;
    record = _record("reviewed-source-context", "reviewed-source", "one");
    record["is_demo"] = False;
    record["source_url"] = "https://example.test/reviewed-notice";
    upsert_access_notice(record);
    view = get_access_context(jid(loc), 150.0).notices[0];
    assert view.state == "current" and not view.is_demo;
}
