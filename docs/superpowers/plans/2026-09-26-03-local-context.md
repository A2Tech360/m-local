# Engineer 3: Local Context and Data Implementation Plan

> **For agentic workers:** Four human engineers run their own models. Implement
> only this mission. Use `superpowers:executing-plans` if available; otherwise use
> the inspect, failing-test, implementation, verification loop. Do not start another
> agent team or modify another owner's production files.

**Goal:** Make one useful piece of local information change what a student sees,
with a visible source, freshness state and honest limits.

**Architecture:** Add a ContextNotice node linked to Location. Upsert reviewed
records through a small JSON adapter and evaluate validity with the server clock.
Keep source evidence, simulated fixtures and normalized records distinguishable.

**Tech stack:** Pinned Jac runtime and graph, JSON fixtures, source ledger.

**Spec:** [Mission](../../START-HERE.md), [contract](../../TEAM-CONTRACT.md),
[workflow](../../TEAM-WORKFLOW.md).

**Continuation:** Travis authorized E4 to finish E3 on 2026-09-27 UTC. Preserve
E3's commits through `32645ea`, integrate runtime `43aa698`, and update existing
PR #4. E2 still owns attaching `AccessContextView` to `OfferView`; E4 rendering
follows that handoff. The server/data handoff does not complete the integrated
offer-explanation acceptance criterion below.

**Source research:** [Free local data guide](../../research/FREE-DATA-SOURCES.md)
and [impact evidence](../../research/LOCAL-IMPACT-EVIDENCE.md). City access notices
remain the required context type. Other sources are prioritized options, not added
acceptance criteria; the U-M event feed is not yet verified working from this machine.

## Global constraints

- Branch: `feat/03-local-context`; keep application logic in Jac.
- One location per restaurant and one context type for this build.
- A notice is current only within its validity window and checked within 24 hours.
- A road closure is not evidence of a closed pedestrian entrance.
- No real business contacts, spending, secret commits or unapproved deployment.

## Files and ownership

Modify `services/importer.jac` and `services/seed.jac`. Create
`services/context_models.jac`, `services/context.jac`, `services/context.test.jac`,
`data/demo/access-notices.json`, `data/sources/README.md`, `docs/data/SOURCES.md`,
`docs/data/RECORD-FORMAT.md`, and `docs/status/engineer-3.md`.
Do not change models.jac, promo.jac, main.jac or theme.jac. Engineer 2 attaches your
returned context; Engineer 4 renders it. Use Engineer 2's money conversion/helper.

## Interfaces

Produce the exact AccessContextView/AccessNoticeView fields and
`get_access_context(location_id: str, now_ts: float) -> AccessContextView` from
TEAM-CONTRACT. Produce an internal importer entry
`upsert_access_notice(record: dict) -> str`, returning the stable graph notice ID.
Invalid records raise a controlled validation error without partial mutation.
The external JSON uses stable `location_slug`; the importer resolves it to the
existing location ID. An unresolved/ambiguous slug is rejected, never guessed.

## Review focus

1. Same source/external ID is refreshed: update one record, without duplicate edges.
2. Notice is expired or checked over 24 hours ago: remove authoritative directions.
3. Source fails: retain the last successful record and its old checked timestamp.
4. Notice targets another location: unrelated offer explanations remain unchanged.
5. Fictional business and real public notice: never imply a verified association.

## Work sequence

### Task 1: Publish the context interface early

- [x] Read the runtime guides, current models/importer/seed and the shared contract.
- [x] Add context model/DTO definitions and the internal helper. An empty notice graph
  returns `state="none"` and `notices=[]`; it does not fabricate a notice.
- [x] Add `empty_context_is_unknown_not_clear_access` and run it. Publish the small
  DTO/helper PR to unblock Engineer 2's OfferView integration.

### Task 2: Build one defensible record pipeline

- [x] Document the JSON schema and required fields, including stable source/external
  IDs, location_slug, version, publisher, URL, checked time, validity interval,
  summary, is_demo and optional explicitly confirmed entrance instructions.
- [x] Add tests `upsert_is_idempotent`, `new_version_updates_same_notice`,
  `invalid_dates_rejected_without_mutation`, and `unknown_location_rejected`.
- [x] Implement validation, source identity lookup and one-record upsert. Deduplicate
  Affects edges. Do not treat the existing skip-on-slug restaurant loader as refresh.
- [x] Review one relevant official public access/construction source and record its
  exact URL, publisher, retrieval time, reuse limitations and supported facts in
  SOURCES.md. Live ingestion is optional; a reviewed small fixture is sufficient.
- [x] Create a clearly simulated notice for a fictional demo location. A real source
  may be shown separately as research, but must not appear to validate a fictional
  storefront's entrance. Never invent a source URL or confirmation.

### Task 3: Prove freshness and repeatable fixtures

- [x] Add `notice_boundary_and_freshness`: a fixture valid [100, 200) with checked_at
  100 is current at 150, needs_recheck at 200, and cannot be current before 100.
  Also test an in-window record checked 86,401 seconds ago and a future checked_at.
- [x] Add `refresh_failure_preserves_old_timestamp` and `other_location_unchanged`.
  Verify needs_recheck never returns a definitive entrance instruction.
- [x] Implement the helper and deterministic clock-based tests. A changed notice
  must alter the corresponding offer context once Engineer 2 attaches it.
- [x] Migrate importer/seed money fields to the shared cents contract and remove
  merchant keys. Seed fictional business data; Engineers 1 and 2 own account
  provisioning. Imported records cannot assign owner_actor_id, passwords or roles.
- [x] Provide Engineer 1 a callable fresh-fixture path for demo.sh. Relative demo
  times are anchored at creation of a new isolated store, not rewritten in an
  existing user's claims. Re-running setup on the same store must not duplicate data.
- [x] Run `./scripts/check.sh` and `./scripts/test.sh context`. Give Engineer 4 example
  none/current/needs_recheck response payloads and source-label wording.
- [ ] Commit, open your PR and record the source evidence, test results and simulated
  versus real-data boundaries in your status.

## Done when

One connected notice can be created, refreshed and expired without duplicates;
freshness and location tests pass; the data's origin is inspectable; the integrated
offer changes its explanation. No unsupported entrance/route claim is presented.

## Starting prompt

```text
You are Engineer 3, local context and data owner for M-Local.
Repository: https://github.com/CosmonautJones/m-local
Read AGENTS.md, docs/START-HERE.md, docs/TEAM-CONTRACT.md,
docs/TEAM-WORKFLOW.md, and your plan:
docs/superpowers/plans/2026-09-26-03-local-context.md.
Implement only this mission on feat/03-local-context in my own clone.
Own importer.jac, seed.jac, the new context model/service/tests, data fixtures
and docs/data. Do not edit services/models.jac, promo.jac or the UI.
Build exactly one useful context feature: a dated, sourced access notice linked
to a location, with idempotent refresh and truthful current/needs_recheck/none
states. Publish the DTO/helper PR early so Engineer 2 can attach it to offers.
Use the shared cents conversion when updating seed/import code. Verify freshness,
boundary times, duplicate handling, failed refresh and unrelated-location behavior.
Keep simulated notices clearly labeled. Do not invent access instructions, source
URLs, merchant participation or relationships between a real notice and a fictional
business. Public source research is allowed; do not contact people or businesses.
Avoid city-wide scraping, new hosted services and extra agents. Use the agreed
runtime and isolated stores. End with commit/PR, exact test results, source ledger,
example context payloads, remaining gaps, and docs/status/engineer-3.md.
```
