# UI refresh: supplied v2 design

Branch: `codex/ui-refresh`. Reference: `Mobile app screens and flows.zip`,
`M Local App v2.dc.html`, selected by Travis on 2026-09-27.

## Current baseline and preservation

The first visual pass mistakenly started from local `b8b15fd`, behind remote
main. This was corrected by rebuilding on fetched `origin/main`
`e518692c5c665b195664418d3ad8b1a43a0fccd3` (13 newer commits). Before publication,
`origin/main` advanced to `3bb922e`; that tip was merged normally, preserving the
latest Insights outcome display and recap changes alongside this refresh.

Before updating, the entire dirty tree was saved in stash
`d0800d59caa90dba2688f705216ed1d8e5323c4d` and the frontend was copied to
`%TEMP%/m-local-ui-refresh-sync-20260927`. The stash is deliberately retained.
The original pre-refresh files also remain in `%TEMP%/m-local-ui-refresh-20260927`.
The branch was fast-forwarded, existing local work was reconciled, and the
visual changes were reapplied to the current frontend.

All tracked backend service files, the scanner controller, and the analytics
calculation/export helper match the current remote baseline. Uncommitted local
simulation tools/data and other pre-existing work are retained. The remote
analytics browser test was kept because it uses the current authentication flow.

## Completed implementation plan

1. [x] Use the latest fetched application as the behavior baseline.
2. [x] Reapply navy, maize, cream, local Figtree typography and supplied branding
   across discovery, forms, claims, scanning, management and insights.
3. [x] Preserve the latest login gate, Account destination, business Insights
   landing, favorites handling, saved claims and feed recovery.
4. [x] Replace the old filter chip rows with a dropdown and one maximum-price
   slider. Preserve time and dietary choices through the existing feed API.
5. [x] Run current regression tests, production build and responsive browser checks.

## Requested behavior

- Before sign-in, only welcome and email authentication screens render. No app
  navigation or feed/merchant/insights requests occur. The Back action returns
  to audience selection. There is no Keep browsing action.
- Signed-out visits and logout always return to the same welcome screen with
  both student and business choices. Old stored audience choices are ignored.
  Valid sessions still restore using Jac's existing token/session mechanism.
  The redundant welcome footer about remembering a path has been removed.
- Merchant navigation keeps the requested wording: Insights / Metrics,
  Manage / Offers, Redeem / Scan, and Account / You.
- The price slider includes free offers and whole-dollar ceilings through $19.
  Its final position is explicitly Any price, including offers above $20.
  Show deals applies the draft; Clear all removes all filters. Escape closes
  the dropdown, discards the draft and returns focus to its button.
- Feed requests use the upstream numeric-range contract (`0-8` for an $8
  maximum). Detail/refresh requests convert this to their existing scalar
  maximum-price contract (`8`), preserving budget explanations.
- The app's existing server-side visibility and authorization rules are
  unchanged. This is a screen gate, not a new backend authorization policy.

## Design differences retained

- v2's dedicated Claims destination and offer-detail favorite button have no
  equivalent implemented action. Saved claims remain available through offers;
  existing favorite controls remain in discovery.
- The latest Account screen and merchant Insights landing are retained.
- Verification remains one accessible input supporting paste and autofill.
- Business image selection retains the existing URL/select review controls.
- All prices, eligibility, saved terms, expiry and analytics come from current
  application responses, not the fictional mockup data.

## Verification

Jac 0.37.23; isolated application copy: `/tmp/m-local-refresh-latest.wewax2`.

- Untouched remote baseline: 101 existing frontend tests passed.
- New dropdown test failed on that baseline, then passed after implementation.
- New detail-price contract test failed with `0-8`, then passed with `8`.
- `bash scripts/check.sh`: passed, with existing compiler warnings.
- `bash scripts/build.sh`: passed, producing `dist/mobile-starter.jab`.
- `bash scripts/test.sh core`: 194 passed in an isolated test store.
- Compiled frontend, onboarding, account/offer, QR/controller, feed reliability,
  tooling and analytics helper tests: 111 passed.
- Playwright checks at 320, 390 and 1440 pixels cover authentication, logout,
  keyboard slider input, combined filters/reset and the existing app screens.
  They use synthetic RPC responses and real compiled UI/assets. Screenshots,
  the report and test/build logs are under `.jac/refresh-latest-evidence/`.
- After merging `3bb922e`, a clean archive of the staged tree at
  `/tmp/m-local-publication.7L7keb` passed the source check, production build,
  and all 112 compiled frontend/tooling/analytics helper tests. This copy
  excluded unrelated untracked files and local working notes.

The localhost:8155 preview runs this isolated copy. No shared demo database was
reset. Real email delivery, physical cameras and physical phones were not tested.
The UI refresh is committed separately on `codex/ui-refresh`. Unrelated local
simulation tools, demo assets and working notes are excluded from this branch's
UI commit and remain in the original checkout.

## Reproduce

After building, in Bash/WSL with the existing UI test dependencies:

```bash
MLOCAL_UI_TEST_MODULES=/home/ravesty/.local/share/m-local/onboarding-check/.jac/ui-test-runtime/node_modules \
  node --test --test-concurrency=2 tests/ui/browser/*.test.mjs tests/ui/*.test.mjs \
  tests/tooling/*.test.mjs tests/analytics/insights.test.mjs
```

In PowerShell, with Python Playwright and Chromium already installed:

```powershell
python tests/ui/refresh_visual.py --url http://localhost:8155 --output .jac/refresh-latest-evidence
```

The visual script intercepts its browser's RPC calls and does not submit business,
claim or redemption mutations to the running application.

## V2 grading fixes (2026-09-27)

A screen-by-screen comparison against `M Local App v2.dc.html` graded the refresh
C+ overall: V2's colors, fonts and brand landed, but most layouts keep the older
structure. Five defects were fixed. Each changes only text, layout or styles;
handlers, RPC calls and filter behavior are unchanged.

- Tab bar: the active tab's maize top border drew as an arc because the tab had
  rounded corners. The tab radius is now 0, so the indicator is a straight bar.
- Feed header: removed the "M-LOCAL · ANN ARBOR" line that repeated the logo.
  Refresh offers and Log out now share one row. The Refresh offers label is
  unchanged because live scripts click it.
- Feed footer: "Showing 1 deal." for a single offer.
- Account: the panel toggle reads "Hide account details" instead of
  "Close account", which read like deleting the account. The closed label stays
  "Account".
- Insights: on phones the period switch is a four-column segmented control, so
  "Year" no longer wraps at 320 px.

Tests: `refresh-contract.test.mjs` adds a test for the header, singular count and
straight tab indicator, which failed before the fix. `account-post.test.mjs`
checks the new toggle label. The Insights change is a phone-width media query that
jsdom can't evaluate, so it was checked in the 320 px screenshot. Results: check
and build passed, 194 core tests, 113 compiled UI/tooling/insights tests, and 28
screenshots with no page errors. Screenshots are in `docs/screenshots/`.

Remaining gaps are layout rebuilds rather than defects: pinned bottom action bars,
the offer detail and claim pass structure, the sign-in audience control, the new
offer editor, and the dark merchant scan screen.
