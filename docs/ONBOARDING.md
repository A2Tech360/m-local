# Email and business onboarding

On a first visit, choose **Find local deals** or **List my business**. The app
opens that path's email form and remembers the choice on this browser, including
after sign-out. The other path's signup and login controls stay hidden. An
existing authenticated account's server role overrides a stale browser choice.
The browser preference controls presentation only; server permissions still
control every action. A new browser or a new temporary phone-link domain asks
again because browser storage is scoped to the site's origin.

Students/community members enter their uniqname beside a fixed `@umich.edu`.
The server constructs the address. Business owners enter their full work email.
A six-digit email code creates an account or resumes its existing Jac session.
No university password is collected. Email verification proves inbox access,
not current enrollment or official U-M endorsement.

## Turn on email delivery

No sender is configured by default. Until one is configured the form reports
that email sign-in is unavailable; it does not pretend to send a code.

### Fastest test setup without a domain

Use a dedicated Gmail account for this small team test. Your real `@umich.edu`
accounts are recipients; you do not need university SMTP access or SSO approval.

1. [Create a Google account](https://accounts.google.com/signup) with a Gmail address.
2. Enable **2-Step Verification** on that account, then create an
   [app password](https://myaccount.google.com/apppasswords) named **M-Local**.
   Google requires you to complete its account/security steps. See Google's
   [app-password instructions](https://support.google.com/accounts/answer/185833).
3. From the checkout that actually hosts the phone demo, run in **PowerShell**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-email.ps1 -Provider gmail
```

Enter the dedicated Gmail address and app password at the hidden prompt.
Do not paste the app password into chat, a command argument, or a Git file.
The helper uses `smtp.gmail.com:465` with TLS, checks authentication without
sending mail, and only then saves `.jac/onboarding.env`. It preserves other
settings in that file. The Gmail sender and login address are the same account.
This does not use your normal Google password or a university password.

The equivalent command in **WSL Bash** is:

```bash
python3 scripts/configure-email.py --provider gmail
```

4. Restart the app. For the phone demo, use **M-Local - Stop Phone Demo**, then
   **M-Local - Start Phone Demo**. The new tunnel has a new phone link.
5. Open that link, enter a real U-M uniqname, receive and enter the six-digit
   code, then sign out and sign in with a fresh code. Check spam folders too.

To check saved credentials without sending email, run the PowerShell helper
with `-Check`, or `python3 scripts/configure-email.py --check` in WSL.
Authentication success does not prove inbox delivery or verify the sender's
authorization at every provider. Complete the real code test before announcing
email signup as ready.

If **App passwords** is missing, confirm the correct dedicated account and
2-Step Verification. Google may withhold the option for some account/security
configurations; do not weaken account security to bypass that restriction.
A domain-backed sender is the alternative. Personal Gmail also has
[sending limits](https://support.google.com/mail/answer/22839) and may reject or
filter mail. Move to a transactional provider before a wider launch.

### Domain-backed sender or another SMTP provider

For example, [Resend SMTP](https://resend.com/docs/send-with-smtp) uses host
`smtp.resend.com`, port `587` with STARTTLS, username `resend`, and an API key as
the password. The setup helper defaults to 587; the host's WSL runtime completed
an encrypted handshake on that port, while port 465 timed out on the test network.
You must own and verify a sending domain; `umich.edu` and `gmail.com` cannot be
verified by the team. Use the helper with `-Provider resend` or `-Provider custom`
(WSL: `--provider resend` or `--provider custom`). A provider account/domain and
credentials still have to be supplied by the team; none were created here.

For manual setup, `.env.example` documents `MLOCAL_SMTP_HOST`, `MLOCAL_SMTP_PORT`,
`MLOCAL_SMTP_USERNAME`, `MLOCAL_SMTP_PASSWORD`, and `MLOCAL_SMTP_FROM`. Edit the
ignored `.jac/onboarding.env` locally using shell-quoted values. `scripts/dev.sh`
loads it on startup; other launchers must source it before starting Jac. The phone
demo launcher does this. Port 465 uses TLS immediately; other ports must support
STARTTLS. Unencrypted delivery is not supported. Keep the file under your local
user's filesystem permissions and never expose it through the web server.

## Business creation and optional AI

After business email verification, choose **Create a business profile**. Business signup
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

Verified on Windows/WSL with Jac 0.37.23: 26 Python onboarding/security/setup/migration
tests, 22 existing core Jac tests, one typed MockLLM extraction test, 18 compiled
browser tests, and 12 QR/scan/proxy tests. `jac check` and the sealed application
build passed (the existing project still emits warnings). The isolated HTTP test
proved actual runtime account/session creation, OTP replay rejection, student
claims, denied business claims, per-account draft isolation and denied anonymous
access. It did not send real mail, call a paid model, or test a physical phone.

### Live email checkpoint (September 26, 2026)

Resend is configured privately on the phone-demo host using a verified sending
domain and encrypted SMTP on port 587. A real U-M verification message showed
**Delivered** in Resend, its recipient supplied the code, and the live application
created an **Email verified** session that survived a page refresh. Travis then
confirmed successful login with two real U-M accounts. Addresses, codes, API keys,
and private account state are excluded from this record and from Git.

The repository remains unconfigured for fresh clones until a host runs sender
setup. This checkpoint proves live email signup; it does not certify physical
camera scanning, hosted AI extraction, or the business approval workflow.
