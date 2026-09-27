# Business Insights: approved first release

Travis approved implementing the proposed private merchant Insights tab on
2026-09-27. Add 7/30/90/365-day views, claims, redemptions, returning accounts,
redeemed offer value, replay of the selected period, and an aggregate-only HTML
recap. Production metrics must never ingest the standalone simulation artifacts.

## Implementation plan

- [x] Add immutable regular-price snapshot and cancellation timestamp to claims.
- [x] Build merchant-scoped analytics from canonical graph records, independent
  of the portal's 30-row history. Derive chronological lifecycle events rather
  than duplicate transaction records into a second store.
- [x] Add responsive Insights UI, filters, playback, visibility-aware refresh,
  error/empty states, and export using only explicitly selected aggregate fields.
- [x] Wire the endpoint and tab into the existing app with narrow changes.
- [x] Verify money, retries, historical cutoffs, returning accounts, timezone
  boundaries, legacy gaps, HTTP ownership isolation, and real redemption updates.
- [x] Run compiler, core tests, build, and browser checks in an isolated copy.

The tracked workspace was clean at kickoff. Existing seed/simulation artifacts
remain intact. Bounded delegation owns new analytics/UI files only; the
coordinator makes the small existing schema, lifecycle, and main app integrations.
This is the approved feature's scope, not a reassignment of unrelated team work.

## API and UI contract

`merchant_insights(days: int = 30)` is a protected server endpoint. It resolves
the authenticated merchant itself; there is no caller-supplied merchant ID.
Accepted day counts: 7, 30, 90, 365. Local dates use America/Detroit. The last
day ends at server `as_of`; prior days end at the following local midnight.

Response shape:

```text
ok: bool, message: str, business_name: str, is_demo: bool
period_days: int, timezone: str, start_date: str, end_date: str, as_of: float
coverage_start_date: str, warnings: list[str], engagement_available: false
frames: list[{day: int, date: str, daily: Metrics, totals: Metrics, offers: list[OfferStats]}]
totals: Metrics, offers: list[OfferStats]
Metrics: claims, redemptions, unique_customers, returning_customers,
         value_cents, savings_cents, savings_known,
         cohort_redeemed, cancelled, expired, pending, unknown_outcomes
OfferStats: id: str, title: str, redemptions: int, value_cents: int
```

All metric fields are nonnegative integers. Frames include a zero baseline at
index 0 and one frame per local calendar day. Empty authorized businesses receive
valid zero frames. Unauthorized callers receive `ok=false` and no private data.

Claims/outcomes describe claims created within the selected period. The company
metrics page shows redeemed, cancelled, and expired outcomes; pending and legacy
unknown outcomes are omitted from that display. Redemptions and value describe
redemptions occurring in the period, including a claim carried over from before
its start. Redemption rate uses `cohort_redeemed / (cohort_redeemed + cancelled
+ expired)`.
Money uses immutable claim prices, not current offer prices. Known discount
baselines contribute only when recorded and valid, with `savings_known` coverage.
Returning customers are distinct accounts redeeming in this period that also
redeemed on an earlier local date at this business, including earlier history.
No account IDs, QR credentials, email addresses, or customer coordinates leave
the server. Offer titles in replay come from redemption-time claim snapshots.

Legacy cancelled claims without a cancellation timestamp have unknown historical
outcomes; do not invent a cancellation date or count them as expired. Missing
timestamps/price evidence are reported in coverage warnings. Demo businesses
remain visibly labeled. Demo offers are excluded from a real business's totals.

The first version computes bounded daily summaries on demand; there is no cache
that can conceal a new redemption. Background rollups can be added after measured
query costs justify them. The UI refreshes on mount, manual refresh, and a visible
30-second interval; account/range changes discard stale responses. Playback freezes
its current recording while new data is available for explicit refresh.

Views, nearby selections, verified visits, payment revenue, customer travel paths,
and causal impact are not inferred. The recap is a visualization of recorded
transaction outcomes. Location maps require a reviewed place association and
separately captured nearby engagement, so they are outside this first release.

## Using the feature

Sign in to an account that owns a business, then choose **Insights**. Select
7, 30, or 90 days, or **Year** for the last 365 local calendar dates through now.
The app refreshes every 30 seconds while visible. Play or drag the timeline to
explore a fixed recording; **Return to latest** resumes current totals.

**Download recap** saves a standalone HTML file with the whole selected period,
even if the replay cursor is on an earlier date. It includes business names,
offer titles, daily aggregates and replay controls. It works offline. The export
uses an explicit field allowlist and drops account, offer and claim identifiers,
QR credentials, unexpected response fields, and private warning text.

Real businesses start with their own recorded activity. The Ann Arbor catalog and
synthetic 200-person simulation remain separate artifacts; this endpoint does
not import them. Demo business activity is visibly labeled in the app and recap.

Historical claims without the new regular-price field can still contribute to
redemption counts and saved offer value, but cannot establish a discount. Old
cancellations without a timestamp stay historically unknown. Older zero-valued
price snapshots cannot distinguish a legitimate free offer from a missing legacy
price; no payment or revenue claim is made from those records.

## Verification commands

From the repository in **WSL Bash**, using pinned Jac 0.37.23:

```bash
bash scripts/check.sh
bash scripts/test.sh core
bash scripts/test.sh insights
bash scripts/build.sh
```

`insights` runs the pure Python calculation checks, Node replay/export checks,
and Jac graph tests in a separate store. Never run graph tests against a shared
demo database. Python date calculations require the IANA timezone database,
available in the supported WSL runtime.

For an already running **isolated** local app, provision demo accounts using
`scripts/provision-demo.py`, restart that same app with its `.jac/qr-demo.env`,
then run the transaction acceptance checks in WSL:

```bash
python3 tests/analytics/http_acceptance.py \
  --api http://127.0.0.1:8143 --accounts /path/to/isolated-app/.jac/qr-demo-accounts.json
```

For Windows Chrome + Python Playwright, run in **PowerShell**:

```powershell
python tests/analytics/test_recap_browser.py
python -u tests/analytics/live_browser.py --ui http://localhost:8142 `
  --api http://127.0.0.1:8143 `
  --accounts '\\wsl.localhost\Ubuntu\path\to\isolated-app\.jac\qr-demo-accounts.json'
```

Use the actual ports and private fixture path. These checks create fictional test
offers in the isolated app. Credentials are not printed. Browser screenshots and
the downloaded recap are stored in ignored `.jac/insights-evidence/`.

## Verified locally on 2026-09-27

- Pinned Jac compiler check and production bundle passed. Existing JSX interop,
  boundary typing, and seed docstring warnings remain; this is not a zero-warning
  repository. The main module explicitly includes the Insights JavaScript helper
  because Jac 0.37.23 does not copy that JSX dependency transitively.
- Core suite: 63 passed. Analytics suite: 9 Python, 6 Node, and 32 Jac checks
  passed; the Jac total includes 5 new graph checks plus imported rule tests.
- Actual HTTP requests with two merchants and two students verified guest/student
  denial, all ranges, idempotent claims, single redemption, original-price value
  and discounts after offer edits, timestamped cancellation, ownership isolation,
  and private-field exclusion. A cold-start catalog initialization gap was found
  and fixed before the successful run.
- Chrome tested the actual authenticated app at desktop and 390px widths. Year
  selection, replay, seek/reset, a committed redemption appearing on the visible
  30-second refresh, download/offline playback, and a delayed response across
  sign-out/business switching passed without browser errors.
- Independent offline recap checks passed hostile-text escaping, aggregate-only
  export, keyboard playback/seek, and mobile layout. A read-only review found no
  actionable auth, aggregation, replay or export defect.

The isolated preview is `http://localhost:8142/` with API port 8143. Its source
and private demo accounts are under `/tmp/m-local-insights-qa-3lcea7d3` in WSL;
the preview must stay attached to that isolated store. These are fictional
accounts exercising actual application transactions, not production customers.
The original simulation preview on port 8768 is unchanged.

This increment is local and has not been deployed to the shared team site.
Physical-device testing and high-volume production query performance are not
established by these checks.
