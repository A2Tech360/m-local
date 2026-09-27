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
- Pending company profiles reopen for editing. Failed loads block empty
  overwrites. Student accounts cannot read, save or import business profiles.
- Approved merchants can edit restaurant profiles, publish offers and edit or
  pause existing offers. Validation failures do not mutate records or show
  success. Existing claims retain their original terms.
- Unfinished offer fields survive tab switches. Pending writes block navigation
  and duplicate submission; restaurant fields are read-only during saves.
- Public phone ingress allows only the two additional protected profile RPCs.

## Verification

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

Screenshots and private account receipts remain outside Git. This pass sends no
email, uses no paid model, and makes no public deployment. Physical phone/camera
testing and business approval remain separate. A verified business application
does not gain merchant authority merely by editing its profile.
