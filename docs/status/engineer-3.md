# Engineer 3 status: local context and data

Continuation on 2026-09-27 UTC: Travis authorized resuming E3 after its owner's
credits ran out. Original E3 commits through `32645ea` are preserved. Integration
starts from runtime `43aa698` (which includes E4 PR #2), using Jac **0.37.23**.
PR: [#4](https://github.com/CosmonautJones/m-local/pull/4), stacked on
`feat/01-runtime-release`; this is not a release to main.

## Delivered

- Added `ContextNotice -Affects-> Location`, `AccessNoticeView`,
  `AccessContextView`, and `get_access_context(location_id, now_ts)`.
- Added source/external-ID upsert validation, slug-to-one-location resolution,
  idempotent refresh, and retained evidence fields.
- Added deterministic context tests for empty/unknown, boundaries, stale/future
  checks, invalid records, idempotency, version refresh, failed refresh retention,
  and unrelated locations.
- Added an explicitly simulated notice fixture. It is linked only to a fictional
  demo business and has no invented entrance instruction or source URL.
- Removed legacy demo entrance assertions and retired merchant keys from committed
  importer/seed records. Preserved E2's integer cents fields through its shared
  `money_to_cents` helper, and left account provisioning with E2.
- Repaired Jac 0.37.23 syntax/type incompatibilities and enabled the context suite
  in the existing isolated test wrapper.
- Published notices under `root.shared`, with read-only access for other sessions.
  The authenticated student who initializes the catalog no longer hides notices
  from other students, guests, or provisioned merchants.
- Reject malformed evidence objects, identity assignment fields, unsafe source
  URLs and ambiguous graph associations before updating a saved notice.

## Consumer handoff

Engineer 2 can import `AccessContextView` and call
`get_access_context(location_id, time.time())` from its server-side offer view.
Engineer 4 should use these source labels:

- `none`: “No reviewed access notice is available. This is not confirmation that
  access is clear.”
- `current`: “Current access notice — {publisher}. Checked {checked_at}. Valid
  until {valid_until}.”
- `needs_recheck`: “Access notice needs rechecking — {publisher}. Do not rely on
  old entrance instructions; check the source before visiting.”

Example payloads:

```json
{"state":"none","notices":[]}
```

```json
{"state":"current","notices":[{"id":"notice-id","summary":"Demo access context for a fictional storefront. Confirm access before visiting.","publisher":"M-Local simulated fixture","source_url":"","checked_at":150,"valid_from":100,"valid_until":200,"state":"current","is_demo":true,"entrance_instruction":""}]}
```

```json
{"state":"needs_recheck","notices":[{"id":"notice-id","summary":"A previously reviewed notice","publisher":"Example publisher","source_url":"https://example.invalid/notice","checked_at":100,"valid_from":100,"valid_until":200,"state":"needs_recheck","is_demo":false,"entrance_instruction":""}]}
```

## Evidence and limits

The [source ledger](../data/SOURCES.md) records the reviewed official City source,
retrieval time, permitted factual use, and its limits. No real City notice is
associated with a fictional restaurant. A vehicle closure never becomes a claim
about a pedestrian entrance without explicit confirmation.

## Verification

Supported host: Travis's Windows 11 laptop, Ubuntu 24.04.3 under WSL, x86-64,
uid 1000, Jac 0.37.23. Tests use fresh native Linux stores, separate from the
running phone preview and its private accounts.

- `bash scripts/test.sh context`: **11 passed**. The original branch failed to
  compile. Added validation regressions failed before repair (8 passed, 3 failed)
  and passed afterward. Freshness checks include both expired/future records and
  the exact 24-hour boundary.
- `bash scripts/test.sh core`: **22 passed**.
- `bash scripts/check.sh`: **exit 0**, warnings remain.
- `bash scripts/build.sh`: **exit 0**, 12/12 server modules; artifact size
  1,691,350 bytes. Building is not proof of serving that artifact.
- Compiled-app DOM, UI and tooling tests: **25/25 passed** with
  `MLOCAL_UI_TEST_MODULES="$PWD/.jac/ui-test-runtime/node_modules" node --test
  tests/ui/browser/*.test.mjs tests/ui/*.test.mjs tests/tooling/*.test.mjs`.
  These UI inputs are synthetic; they do not establish physical camera behavior.
- `python3 tests/integration/context_http.py`: **9/9 passed** against real Jac
  HTTP authentication and persistence on a randomly allocated loopback port.
  Four reads cover the seeding student, guest, second student and provisioned
  merchant. Restart preserves notice ID, source labels and dates. Jac's transient
  response-object `_jac_id` is excluded; every declared DTO field is compared.
- The HTTP check uses `tests/integration/context_probe.jac`, a test-only adapter
  to the real helper. It does **not** prove `OfferView.access_context` integration
  or UI rendering. The adapter supplies the server clock and is never imported
  by the application.
- Logs are ignored under `.jac/e3-resume/`. HTTP fixtures and private server logs
  remain in WSL's cache; passwords, tokens and account IDs are not printed.

This supersedes E3's unsupported Intel-Mac execution attempt, not the requirement
for a real Mac pass. Physical camera scanning, production artifact serving and
the full integrated context UI remain unverified by this increment.

## Remaining integration

- Engineer 1 reviews the context wrapper and callable fresh-fixture path
  `seed_demo_access_notices`. Normal `seed_demo` anchors dates on first creation;
  explicit fixture refresh is for a new isolated store only.
- Engineer 2 must attach the returned context to `OfferView` with the server clock.
  `location_id` is already available; cents-schema migration is preserved here.
- Engineer 4 must render source, freshness, demo label, and the no-directions
  behavior for `needs_recheck`.
- The human review ring and required Baz review remain pending. Automated review
  and CI do not replace those reviews or organizer-confirmed competition rules.
