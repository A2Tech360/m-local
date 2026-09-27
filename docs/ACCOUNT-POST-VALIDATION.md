# Account, company profile and offer completion

Validated September 26-27, 2026 on Windows 11 with WSL, Jac 0.37.23 and Chromium.
The source snapshot lives at
`/home/ravesty/.cache/m-local/account-post-20260926/onboarding-check`.
Its private local test data is separate from the running phone demo.

## Delivered behavior

- Explicit create-account and returning sign-in modes for U-M and business users.
  Returning sign-in preserves the stored name and account type.
- Authenticated account display-name editing, cancel/retry, and read-only email
  and access status. Edits persist and appear in the current session.
- Verified business profiles activate immediately on explicit save, including
  previously pending profiles. Failed loads block empty overwrites. Student
  accounts cannot read, save or import business profiles.
- Business owners can edit restaurant profiles, publish offers and edit or
  pause existing offers. Validation failures do not mutate records or show
  success. Existing claims retain their original terms.
- Unfinished offer fields survive tab switches. Pending writes block navigation
  and duplicate submission; restaurant fields are read-only during saves.
- Public phone ingress allows only the two additional protected profile RPCs.

## Self-service business verification (September 27)

Travis removed the approval gate for team testing. No business-approval page
exists. Verified business accounts now explicitly save a complete profile to
create their owned restaurant; the UI refreshes the server session and opens
Manage. Older pending profiles take the same path. Email proof, representation
confirmation and account isolation remain required.

| Check | Result |
|---|---|
| Python onboarding/security/profile tests | 46 passed |
| Isolated Jac core/QR/session/activation checks | 63 passed, including imported attached tests |
| Compiled browser tests with synthetic RPC responses | 38 passed |
| QR rendering, scanner, proxy and ingress tests | 15 passed |
| Whole application `jac check` | Passed; existing warnings remain |
| Sealed production build | Passed; `dist/mobile-starter.jab`, 1,834,001 bytes |
| First publication after cold start | Passed; one offer created, original ID retained on edit |
| Real HTTP account/business/post acceptance | Passed; pending-to-active transition, immediate publishing, distinct owners for identical business names, wrong-owner edit/redemption denial |
| Real OTP and QR HTTP checks | Passed; replay rejection, account isolation, claim and redemption races |
| Real Chromium at 390px | Passed; new verified business setup, immediate Manage, publish/reload, company edit/reload; existing merchant flow also passes with no page errors or horizontal overflow |
| Restart persistence | Passed; account/session names, company details, self-service merchant ownership, and published offer retained |

Activation uses an inactive private ownership reservation, commits one restaurant
and location, then activates ownership while holding the existing mutation lock.
A fault-injection test stops after graph commit and proves no premature merchant
grant, exactly one restaurant/location, and recovery using the same ID. Repeated
saves and explicit environment ownership overrides also pass. Compiled UI tests
cover saved-but-session-refresh failure with retry and no duplicate save.

Independent review found and resolved signup/editor field-limit differences.
Name, cuisine and address now use the merchant editor's 120/80/240 limits, and
unsupported control characters are rejected before activation. No remaining
concrete defects were identified by the final source review.

## Original account/post verification (before self-service activation)

| Check | Result |
|---|---|
| Python onboarding/security/profile tests | 38 passed |
| Isolated Jac core/QR/session tests | 32 passed |
| Compiled browser tests with synthetic RPC responses | 34 passed |
| QR rendering, scanner, proxy and ingress tests | 15 passed |
| Whole application `jac check` | Passed, existing warnings remain |
| Sealed production build | Passed; `dist/mobile-starter.jab`, 1,862,592 bytes |
| Real Chromium at 390px | Merchant sign-in, draft retention, publish/reload, account name edit/reload, pending company edit/reopen passed; no page errors or horizontal overflow |
| Real account/company/post HTTP acceptance | Passed, including exactly one post before and after editing |
| First publication after restart | Passed; exactly one public offer, then edit retained its ID |
| Real QR HTTP acceptance | Passed, including simultaneous claim and redemption races |
| Restart persistence | Account name/session, pending company edits and published offer retained |

The real HTTP acceptance suite covers OTP session creation and replay denial,
returning sign-in, account isolation, immutable identity, company draft isolation,
anonymous and wrong-role denial, merchant profile validation, offer publication,
editing, pause/resume and exact post counts. QR acceptance also verifies two
students sharing the catalog, simultaneous last-unit claims, immutable claim
terms, wrong-merchant denial and simultaneous redemption.

The startup regression matters: Jac retries a function's first graph write after
detecting that the request needs a write transaction. The prior `_unlock()`
committed dirty objects while the retry exception unwound, producing two posts
from the first publish. Cleanup now commits only completed attempts and releases
the lock on failures. Unit regressions reproduce abandoned-write leakage and
descriptor leakage; `cold_post_http.py` checks the actual first HTTP publication
after a server restart. Run this before any other `save_offer` request.

## Repeat the checks

In **WSL Bash**, in a disposable copy with Jac 0.37.23:

```bash
bash scripts/check.sh
bash scripts/test.sh onboarding
bash scripts/test.sh core
# Stop that copy's server before building.
bash scripts/build.sh
node --test tests/ui/*.test.mjs tests/tooling/*.test.mjs
MLOCAL_UI_TEST_MODULES=/home/ravesty/.local/share/m-local/onboarding-check/.jac/ui-test-runtime/node_modules \
  node --test tests/ui/browser/*.test.mjs
```

The HTTP scripts require an isolated `onboarding-check` workspace on port 8240,
local demo provisioning, and a restarted server with `.jac/qr-demo.env` sourced:

```bash
python3 tests/integration/cold_post_http.py --api http://127.0.0.1:8240 --accounts .jac/qr-demo-accounts.json
python3 tests/integration/account_posts_http.py
python3 tests/integration/qr_http.py --api http://127.0.0.1:8240
# Restart the same isolated server, then verify the saved receipt:
python3 tests/integration/account_posts_http.py --verify-restart
```

The opt-in real browser script requires Python Playwright and Chromium. From
**PowerShell** in this checkout, with the isolated server running:

```powershell
python tests/ui/live_account_posts.py --workspace '\\wsl.localhost\Ubuntu\home\ravesty\.cache\m-local\account-post-20260926\onboarding-check' --screenshots '.jac\validation\account-post'
```

Screenshots and private account receipts remain outside Git. These checks send
no email, use no paid model, and make no public deployment. Physical phone/camera
testing remains separate. Business approval was removed at Travis's request on
September 27. A verified business can save its own profile to enable publishing;
the server generates and persists its ownership privately.
