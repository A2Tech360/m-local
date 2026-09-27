# One-click phone demo (Windows)

Double-click **Start Phone Demo.cmd** in the repository. It prints an HTTPS link
and opens the app. Send that link to teammates; iPhone Safari and Android Chrome
can visit it on Wi-Fi or cellular. No phone installation is needed. Keep the
launcher window open and the host computer awake and online.

Double-click **Stop Phone Demo.cmd** to close sharing. Starting again gives a new
link. This is a temporary team demo, not permanent hosting. Cloudflare Quick
Tunnels have no uptime guarantee. A stable, always-online URL needs a separate
hosted deployment. [Cloudflare documentation](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/).

## First launch

The Windows host needs Node.js 22+, Ubuntu in WSL, and the repository's pinned
Jac runtime. If Jac is missing, run `bash scripts/setup.sh` in Ubuntu/WSL from
the repository. The launcher gives an error rather than changing a global runtime.
Phones and teammates visiting the link need only their browser.

The launcher downloads Cloudflare's official Windows x64 helper, version 2026.9.3,
and verifies its SHA-256 on every launch. It runs the compiled Jac app on loopback
port 8200, a restricted gateway on 8280, and an outbound HTTPS tunnel. It leaves
the existing 8000/8100 development servers alone and does not change firewall rules.
First launch includes compilation, dependency downloads, and private demo account
provisioning; allow several minutes.

Private student and merchant logins are saved in **.jac/phone-share/accounts.json**.
Assign `student_a` and `student_b` to separate testers; merchants use
`merchant_leaf` and `merchant_noodle`. Keep this file private. The public link does
does not disclose those logins. Browsing works without signing in. Keep demo
businesses/offers fictional. Real U-M accounts can register through the email-code
flow after the host configures a sender; raw Jac registration remains blocked.

For Resend, double-click **Set Up Email.cmd**, use an address on a verified sending
domain, and enter the dedicated sending API key at the hidden prompt. The helper
uses encrypted SMTP on port 587 and saves credentials outside Git. Restart the
phone demo after setup. See [email onboarding](ONBOARDING.md) for other providers
and the live two-account verification checkpoint. Configuring one checkout does
not configure another checkout or another computer.

The launcher copies application source to a stable, separate WSL directory for
faster compilation. Its path is in `.jac/phone-share/runtime-path.txt`. That
directory holds this demo's persistent database. Restarting refreshes source,
retains accounts and claims, and does not reset another preview's data. Existing
test accounts from a different preview do not apply to this separate database.
Old seed offers may be closed to QR claims; a provisioned merchant can create a
new fictional offer for a claim-and-redeem test.

## Everyday use

1. Double-click Start Phone Demo and wait for **OPEN ON YOUR PHONES**.
2. Open the link on each phone. Use verified U-M email signup or share a private
   demo login separately. Each browser requests its own verification code.
3. For a merchant camera test, sign in as the merchant and allow camera access
   when prompted. HTTPS provides the required secure origin; a physical scan still
   needs to be tested on the actual phone.
4. Stop Phone Demo closes the link. Restart after pulling application changes.

The current URL is also in `.jac/phone-share/link.txt`. Double-clicking Start
again reopens the existing link. After stopping, wait a few seconds for Jac to
release its database before starting again.

PowerShell alternatives (from the repository):

```powershell
.\scripts\phone-share.ps1
.\scripts\phone-share.ps1 -Stop
.\scripts\phone-share.ps1 -NoBrowser
```

## Troubleshooting and scope

- Logs are in `.jac/phone-share/`, plus the launcher console. Do not publish logs
  containing account or request information.
- If a required port is busy, the launcher reports it without terminating another
  process. Stop the conflicting preview deliberately or use a different host.
- If startup fails, read `server.log` and `server.err.log`. Tunnel failures are in
  `tunnel.err.log`. A venue network may block the tunnel; try a trusted hotspot.
- Closing the launcher abruptly can leave Jac running. Use Stop Phone Demo and
  wait a few seconds before starting again. The stop file reaches the WSL supervisor.
- Camera scanning is a physical-device acceptance check. A working HTTPS link
  alone is not a passing camera test.
- This gateway permits compiled assets, login, and the app's named RPCs. It blocks
  development modules, filesystem routes, graph/admin APIs, and raw Jac signup.
  The app's email-code signup and business-draft RPCs are allowed and rate limited.
  App identity and business rules remain enforced by Jac.

## Implementation and verification plan

1. Reuse the integrated Jac 0.37.23 application without changing its UI or rules.
2. Add isolated startup/shutdown, private accounts, and an allowlisted gateway.
3. Verify forwarding and blocked routes, real startup, HTTPS browsing, sign-in,
   shutdown, restart, and preservation of the demo database.
4. Record physical iPhone/Android camera results separately when humans run them.

Automated gateway check: `node --test tests/tooling/phone-share.test.mjs`.
Windows shutdown check: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File
tests/tooling/phone-stop.test.ps1`. It mocks process termination and never stops
the running demo. It reproduces the concurrent-exit race observed during restart.

## Verified on September 26, 2026

Windows PowerShell 5.1 launcher with Ubuntu/WSL, Jac 0.37.23, Node 22.19.0,
and the application at runtime merge `23678f9` (initial launcher checkpoint,
before the later email-onboarding integration):

- Four gateway/tooling tests passed. A regression reproduced the compiled
  `/static/client.js` route being blocked; it passes after the allowlist fix.
- Actual compiled app startup, account provisioning, stop, and restart passed.
  All three owned Windows processes exited after Stop. Accounts survived restart.
- HTTPS HTML/client bundle and live offer discovery loaded in the Codex browser.
- Real HTTPS API calls passed student/merchant sign-in and role checks, publication,
  claim, QR preview, redemption, and repeated-redemption rejection.
- Public admin, graph, environment-file, development filesystem, and signup
  routes returned 403. Private passwords and QR payloads were omitted from evidence.
- Physical phone layout/camera, native mobile packaging, long-term uptime, and
  claim persistence across an additional restart were not certified by this run.

Travis's desktop has Start/Stop shortcuts targeting this checkout. Keep this
worktree available while the shortcuts and running demo use it.

The later onboarding integration was exercised through the same gateway: real
Resend delivery, U-M account creation, a verified session retained after refresh,
and preserved demo accounts after restart. Travis confirmed two real U-M logins.
The current live accounts and sender configuration remain private to this host.
