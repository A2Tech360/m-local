# Themes, business pages, and compact phone controls

Branch: `codex/themes-business-profile`, based on `main` at `0091778`.

## Intent and implementation plan

Extend the approved navy/maize refresh for phone demos while preserving sign-in,
offer eligibility, saved claims, QR redemption, and merchant ownership.

- [x] Restart the existing hosted gateway after the current deployment completes;
  verify public health, both logos, and the font return HTTP 200.
- [x] Add System, Light, and Dark appearance preferences shared across all screens.
- [x] Add an authenticated business projection and a customer-facing profile.
- [x] Integrate business-name navigation, merchant preview, and explicit favorite removal.
- [x] Move logout beside the logo, style secondary actions as buttons, and put a
  compact Filters trigger beside Refresh offers.
- [x] Verify compiled flows, backend privacy, and responsive layouts in both themes.

## Behavior

Appearance defaults to the device preference. An explicit Light or Dark selection
is remembered in `mlocal_theme`, independently of the login token. System follows
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

The [official A2Tech guide](https://jachacks.org/a2tech-guide/), rechecked on
2026-09-27, requires meaningful Jac use and at least 40% Jac, but does not define
whether percentages use lines, bytes, or which test/tooling files count.

At `f8902d6`, counting tracked source files (excluding assets, dependencies, build
output, data, and documentation):

| Scope | Jac nonblank lines / total | Jac by nonblank lines | Jac by bytes |
| --- | ---: | ---: | ---: |
| App: main/theme, client, services; excluding tests and declarations | 4,301 / 6,101 | 70.50% | 57.47% |
| All source, including tests, declarations, and hosting/tooling scripts | 5,812 / 14,046 | 41.38% | 33.41% |

Source extensions counted: `.jac`, `.jsx`, `.mjs`, `.js`, `.py`, `.ts`, `.tsx`,
`.sh`, `.ps1`, `.cmd`, `.html`, `.css`. Nonblank lines include comments. App scope
does not include `.test.*` or `.d.ts` files. Byte counts use the files on disk.

Jac owns the entry point, graph models, authorization orchestration, offers,
claims, redemption, and business-profile endpoint. JSX handles selected client
components; Python supports email, onboarding storage, imports, and analytics.
This demonstrates substantial Jac use, but is not an unconditional eligibility
claim: the all-source byte share is below 40%. Confirm the organizer's counting
method and rerun the inventory on the submission commit. Do not remove tests,
pad source, or change file classification to manufacture a percentage.
