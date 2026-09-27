# Access-notice record format

The reviewed JSON adapter accepts one object per notice. Identity is the stable
pair `source_id` + `external_id`; a changed `version` refreshes that same graph
notice instead of adding another record or `Affects` edge.

```json
{
  "source_id": "publisher-system",
  "external_id": "stable-upstream-id",
  "location_slug": "existing-restaurant-slug",
  "version": "upstream-revision",
  "publisher": "Publisher name",
  "source_url": "https://publisher.example/notice",
  "checked_at": 1760000000.0,
  "valid_from": 1760000000.0,
  "valid_until": 1760086400.0,
  "summary": "Plain factual summary",
  "is_demo": false,
  "entrance_instruction": "Only explicitly confirmed instructions",
  "original_evidence": {},
  "normalized_evidence": {}
}
```

Required fields are `source_id`, `external_id`, `location_slug`, `version`,
`publisher`, `source_url`, `checked_at`, `valid_from`, `valid_until`, `summary`,
and `is_demo`. `entrance_instruction`, `original_evidence`, and
`normalized_evidence` are optional. Timestamps are UTC epoch seconds, validity is
the half-open interval `[valid_from, valid_until)`, and `valid_until` must be
strictly later than `valid_from`.

`source_url` may be empty only if `is_demo` is true. `location_slug` must resolve
to exactly one existing restaurant and exactly one existing location; it is never
guessed. Imports reject owner/account fields (`owner_actor_id`, password, role,
roles, and the retired `merchant_key`).

The service reports `current` only when the interval contains the server clock,
`checked_at` is no more than 24 hours old, and it is not future-dated. Otherwise
the record is `needs_recheck`; its source and summary may remain visible, but its
entrance instruction is blank. With no records, context is `none`, which means
unknown—not clear access.
