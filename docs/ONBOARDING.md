# Email and business onboarding

Students/community members enter their uniqname beside a fixed `@umich.edu`.
The server constructs the address. Business owners enter their full work email.
A six-digit email code creates an account or resumes its existing Jac session.
No university password is collected. Email verification proves inbox access,
not current enrollment or official U-M endorsement.

## Turn on email delivery

No sender is configured by default. Until one is configured the form reports
that email sign-in is unavailable; it does not pretend to send a code.

In **WSL Bash**, from the checkout:

```bash
mkdir -p .jac
cp .env.example .jac/onboarding.env
chmod 600 .jac/onboarding.env
```

Edit `.jac/onboarding.env` locally. Set `MLOCAL_SMTP_HOST`, `MLOCAL_SMTP_PORT`,
`MLOCAL_SMTP_USERNAME`, `MLOCAL_SMTP_PASSWORD`, and `MLOCAL_SMTP_FROM`.
Use a sender address authorized by your email provider. Never use a university
password here. `scripts/dev.sh` loads this ignored file on startup. Other launchers
must source it before starting Jac. Port 465 uses TLS immediately; other ports
must support STARTTLS. Unencrypted delivery is not supported.

For example, [Resend SMTP](https://resend.com/docs/send-with-smtp) uses host
`smtp.resend.com`, port `465`, username `resend`, and an API key as the password.
Configure an address on your verified sending domain. A provider account/domain
and credentials still have to be supplied by the team; none were created here.

Restart, request a code to an inbox you control, verify it, sign out, and sign
back in with a fresh code. Check spam folders and sender-domain configuration
if delivery fails. Provider acceptance is not proof of inbox receipt.

## Business creation and optional AI

After email verification, choose **Create a business profile**. Business signup
opens this form immediately. Paste a public `https://` homepage or type details
manually. Import reads at most the homepage and one same-site menu HTML page;
PDF menus remain links. JavaScript-only sites may require manual entry. It reads
structured business data, metadata, text, menu URLs and image URLs. Images are
linked for selection/review; they are not copied into an owned media library.

To additionally organize site text with Jac's real `by llm()` implementation,
set `MLOCAL_IMPORT_MODEL` and its provider credential in the same private env
file, run `jac install` with the pinned runtime, then restart. For example, `MLOCAL_IMPORT_MODEL='gpt-4o-mini'` with
`OPENAI_API_KEY`. This sends bounded public website text to that provider.
No model call occurs when `MLOCAL_IMPORT_MODEL` is empty. Metadata import and
manual editing continue if AI is unavailable. No model has authority to publish,
assign roles, fetch arbitrary URLs, or perform actions from website instructions.

Review facts/prices, select permitted image/menu URLs, confirm representation and
content rights, and save. This creates a **private pending business application**.
It does not publish a public restaurant, create offers, or grant merchant access.
Trusted merchant provisioning still controls existing restaurants. A reviewer UI
and the approval-to-listing workflow are a later increment; applications are
currently retained locally in the private onboarding store.

## Existing demos and deployment

Before updating an already-provisioned demo, run in its actual runtime directory:

```bash
python3 scripts/enable-demo-students.py --state-dir .jac
source .jac/qr-demo.env
```

This appends explicit student root IDs from the existing private account file.
It never changes accounts, passwords, claims or merchant ownership. New provisioning
already writes this allowlist. Restart the server with that environment. Generic
runtime accounts cannot claim offers until verified or explicitly provisioned.

Only expose the compiled app and exact application RPCs through public ingress.
Add `request_email_code`, `verify_email_code`, `get_business_draft`,
`import_business_website`, and `save_business_draft` to the phone gateway allowlist.
Keep `/user/register`, arbitrary RPCs, graph/admin endpoints and private files
blocked. Apply `scripts/onboarding-ingress.mjs` using a trusted client IP from
your reverse proxy (never arbitrary `X-Forwarded-For` from a browser).

Private OTP/account/draft state is in `.jac/onboarding/`, or an absolute
`MLOCAL_ONBOARDING_DIR`. Preserve it together with the Jac identity database.
It contains personal data and a mode-0600 HMAC key; do not commit or expose it.
SQLite transactions serialize verification across processes on one host. This
implementation is for a single host, not independent replicas. A recovery journal
finishes interrupted account provisioning without taking over foreign accounts.

Codes expire after 10 minutes, have five guesses, are single-use, and are HMAC
digests at rest. Sending has a 60-second cooldown, five sends/address/hour, and
global spending caps. Ingress adds per-client limits. Drafts are read/saved only
under the authenticated request's actor. Website requests validate all DNS answers,
pin the chosen public IP while checking TLS for the hostname, bound response sizes,
and obey robots restrictions. The model sees source text as untrusted data.

## Verification commands

```bash
bash scripts/test.sh onboarding
bash scripts/check.sh
bash scripts/test.sh core
bash scripts/build.sh
node --test tests/ui/*.test.mjs tests/tooling/*.test.mjs
# Requires the existing jsdom test runtime and a compiled .jac/client/dist:
MLOCAL_UI_TEST_MODULES=/path/to/ui-test-runtime/node_modules node --test tests/ui/browser/*.test.mjs
```

`tests/integration/onboarding_http.py` exercises actual Jac identities/sessions
using locally injected test challenges. Run it only in a disposable workspace
named `onboarding-check`, with a local server at port 8240. It sends no email and
does not prove real inbox receipt. Real model extraction and physical phone
behavior need separate checks with configured services/devices.

### Implementation checkpoint

Verified on Windows/WSL with Jac 0.37.23: 21 Python onboarding/security/migration
tests, 22 existing core Jac tests, one typed MockLLM extraction test, 18 compiled
browser tests, and 12 QR/scan/proxy tests. `jac check` and the sealed application
build passed (the existing project still emits warnings). The isolated HTTP test
proved actual runtime account/session creation, OTP replay rejection, student
claims, denied business claims, per-account draft isolation and denied anonymous
access. It did not send real mail, call a paid model, or test a physical phone.
