# Themes, business pages, and compact phone controls

Branch: `codex/themes-business-profile`, initially based on `0091778` and now
updated with `main` at `9a2980e`, including the Ann Arbor dataset increment.

## Intent and implementation plan

Extend the approved navy/maize refresh for phone demos while preserving sign-in,
offer eligibility, saved claims, QR redemption, and merchant ownership.

- [x] Restart the existing hosted gateway after the current deployment completes;
  verify public health, both logos, and the font return HTTP 200.
- [x] Add shared light/dark appearance with an icon-only sun/moon toggle.
- [x] Add an authenticated business projection and a customer-facing profile.
- [x] Integrate business-name navigation, merchant preview, and explicit favorite removal.
- [x] Move logout beside the logo, style secondary actions as buttons, and put a
  compact Filters trigger beside Refresh offers.
- [x] Verify compiled flows, backend privacy, and responsive layouts in both themes.

## Behavior

Appearance defaults to the device preference until the sun/moon button is tapped. The 44px icon-only button has an accessible action label and tooltip. An explicit Light or Dark selection
is remembered in `mlocal_theme`, independently of the login token. The initial system preference follows
device changes. Storage denial does not prevent an in-tab selection. The QR
credential stays black on a white quiet zone in either theme.

Both themes use one transparent logo silhouette with identical geometry. The
wordmark changes navy/cream while the detached maize square remains recognizable.
The welcome card's square reverses to navy against its dark-mode maize surface.
Surface, text, border, and logo colors transition together over 220 ms; reduced
motion disables transitions, including the page background.

Business names and saved favorites open a business page. Offer titles still open
the existing detail/claim screen. A profile opened from an offer returns to that
offer. Favorites have a separate remove button, including businesses with no
current offer. Manage provides an owner preview of the same public information.

`get_business_profile(slug="", offer_id="")` requires authentication. Explicit
slugs resolve exactly; offer IDs resolve the graph-linked business. With neither
argument, a merchant's trusted ownership resolves their own business. The session
`restaurant_id` is a graph node ID and must never be treated as a slug.

The response includes business name, cuisine, description, address, neighborhood,
dated unverified access notes, and published active/upcoming/sold-out offers.
Paused, expired, draft, and disabled sample listings are excluded. No owner fields
or claim credentials are returned; opening an offer uses the original endpoint
for caller-specific claim state.

## Boundaries and deployment

Photos, opening hours, telephone, and public website fields are not available in
the current business graph. This increment does not invent those details or add
an unverified “open now” status. Existing self-service business slugs contain an
actor identifier; that established identifier format needs a separate migration
if it is to change.

The logo/gateway restart is live. New features stay on this branch until reviewed
and merged. Both application and gateway must be updated for the new profile RPC:
the app updater does not reload gateway code automatically. Follow the controlled
helper restart in `HOSTING.md`, waiting for the old launcher to exit completely.

Business-profile tests are included in the isolated core suite. Frontend fixtures
are synthetic and do not prove real email delivery or physical phone-camera use.

## Verification on 2026-09-27

- Jac 0.37.23 source check and production build passed from an isolated source
  copy at `/tmp/m-local-theme-profile.3mt48O`.
- Core/backend suite: 274 passed in its separate disposable test store.
- Compiled frontend, UI helpers, gateway, tooling, and analytics: 127 passed.
- Real HTTP profile acceptance: 30 checks passed, including two locally verified
  accounts, real business activation/offer/claim, owner preview with no offers,
  guest 401, paused-offer exclusion, and absence of the actual claim credential
  from both member and owner profile responses. No email was sent.
- Chromium visual checks: 66 screenshots at 320, 390, and 1440 pixels in both
  themes, no page errors or horizontal/control overflow. The compact toolbar
  stayed on one row; the logo loaded and the QR quiet zone remained white.
- A long-feed probe confirmed opening the twelfth offer's business starts with
  the profile's back control visible.
- Independent code review found the graph-ID/slug and empty-favorite-removal
  issues; both were fixed and covered before final validation.
- The shared-logo follow-up passed source check, production build, and all 127
  UI/tooling checks from `/tmp/m-local-brand-theme.rFYlZj`. All 66 responsive
  screenshots passed again. Chromium additionally observed an intermediate color
  during the 220 ms theme transition, checked the reversed welcome accent,
  verified unchanged logo bounds, and verified immediate reduced-motion changes.

Visual evidence: `.jac/theme-profile-evidence/`. Reproduce after building:

```powershell
python tests/ui/theme_profile_visual.py --url http://localhost:8155 --output .jac/theme-profile-evidence
```

Real HTTP checks require the specifically isolated workspace and environment
documented in `tests/integration/business_profile_http.py`; never run its
fixture setup against the public demo or shared account store.

## Jac language inventory

Travis confirmed that GitHub's language bar is the acceptance measure. GitHub
uses source bytes, not our earlier application-only or nonblank-line counts.
The [official A2Tech guide](https://jachacks.org/a2tech-guide/) requires meaningful
Jac use and at least 40% Jac. Recheck the actual submission commit.

GitHub's main inventory at `9a2980e` is Jac 270,440 bytes, Python 281,317,
JavaScript 212,112, PowerShell 32,634, Shell 18,575, and Batchfile 632: **33.15% Jac**.
Our Git-blob inventory matches all six API totals exactly, including Python type
stubs and Linguist's default exclusion of generated TypeScript declarations.
`scripts/check-jac-share.py` records this repository-specific mapping and CI
requires at least 40% on the actual commit being tested. Recheck the mapping when
adding languages or vendored code. No Linguist classification overrides were added.

The migration moves actual onboarding, account, business-page, offer-editor,
filter, Insights, and shared presentation components into native Jac. Browser
camera and theme adapters remain JavaScript. Authorization, graph models,
offers, claims, and redemption retain their existing Jac implementation; email,
storage, import, and analytics support remain Python. Tests and operational code
continue to count. No tests were removed or source padded to change the ratio.

Follow-up plan:

- [x] Convert onboarding/account, business profile, offer editor/filters, Insights,
  and shared UI primitives into real Jac components.
- [x] Audit shared theme use, including camera framing and the downloadable recap.
- [x] Run source/build, compiled interaction suites, and responsive checks.
- [x] Verify the final committed byte share exceeds 40% after latest main integration.

The downloaded recap uses the same navy/maize palette and follows the viewer's
device theme. It stays self-contained, with a system sans-serif fallback when
Figtree is unavailable. Export data and replay behavior are unchanged.

GitHub's visible repository language bar reflects its default branch; it will
continue to show main's inventory until this branch is merged and Linguist
refreshes it. The branch gate does not change that public bar.

### Native Jac migration verification

The final source tree contains **374,741 Jac bytes / 912,955 source bytes = 41.05%**.
The Git-blob check includes the new dataset code from main. Reproduce with
`python scripts/check-jac-share.py --min-jac 40` after checking out the commit.

- Jac 0.37.23 project check and full production build passed. The final local
  preview is `/tmp/m-local-jac-ui.jb0mt7`, served at `http://localhost:8155`.
- All 129 compiled frontend, helper, tooling, and analytics tests passed. Native
  Insights coverage includes range switches, replay, stale responses, retry,
  retaining the last recording on failure, and full-period recap export.
- The unchanged backend passed all 274 isolated core tests during this migration.
  All 18 dataset tests also passed after incorporating latest main.
- Final native UI: 132 screenshots at 320/390/1440 pixels across both themes,
  with no page errors or horizontal/control overflow. Includes verification,
  business onboarding, tastes, editor, scanner, and empty/error states.
- Real CSS interpolation, fixed logo bounds, dark-card accent reversal, and
  reduced-motion overrides passed. Downloaded recaps also passed phone-width
  light/dark rendering plus reset/period-total interaction checks while offline.
- Independent generated-code review caught and corrected a Jac string-comprehension
  lowering issue in verification input before this branch was pushed. Existing
  login/re-login tests verify the explicit character-loop replacement.

Physical iPhone Safari and camera hardware remain separate device checks.
