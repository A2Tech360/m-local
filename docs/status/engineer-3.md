# Engineer 3 status: local context and data

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
  importer/seed records. Account provisioning and the shared cents conversion are
  owned by Engineer 2 and must be merged before seed/import money fields can move
  from this baseline's float schema to the contract's `*_cents` fields.

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

- JSON fixture parsed successfully with `python3 -m json.tool`.
- Jac runtime execution is pending a supported host: Engineer 1’s pinned 0.37.23
  release has no Intel macOS binary, and this host rejected the ARM binary. Run
  `bash scripts/check.sh` and `bash scripts/test.sh context` after the runtime
  branch is merged or from its supported Linux/Apple-Silicon environment.

## Remaining integration

- Engineer 1 must merge/provide the context test wrapper and fresh `demo.sh` path.
- Engineer 2 must attach the returned context to `OfferView` with the server clock
  and complete cents-schema migration using `services/money.jac`.
- Engineer 4 must render source, freshness, demo label, and the no-directions
  behavior for `needs_recheck`.
