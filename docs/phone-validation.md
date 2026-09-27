# Phone UI and QR validation

Updated 2026-09-26. This document separates automated checks from physical camera evidence.

## Implemented flow

- Guests browse without supplying an identity. Provisioned accounts sign in using Jac's `jacLogin` and sign out using `jacLogout`; the server supplies the student/merchant role.
- A student claims once, sees a QR and the saved title, integer-cent price, terms, eligibility and deadline. The QR hides itself at the saved deadline. Refresh and cancellation remain available.
- A merchant starts the camera, scans a claim, reviews the server-resolved saved terms and explicitly confirms redemption. A scan does not redeem. Recent claims contain no student identity or QR credential.
- Camera permission denial, absent/busy camera, unsupported browser API and insecure origin have actionable messages. Starting again is explicit. Cancellation, navigation, page hiding and component unmount stop capture; delayed callbacks cannot restore a cancelled preview.
- Repeated detections are latched before awaiting the read-only resolve call. A failed confirmation releases its busy state and permits retry. Jac remains authoritative for ownership, expiry and single use.
- The browser validates only the agreed credential shape: `mlocal:v1:` followed by canonical 43-character unpadded base64url encoding of 32 bytes. Scanned URLs are rejected and never opened.

The React bridge in `client/qr.jsx` is limited to QR rendering and browser video capture, which MobUI does not expose. The screen, session adapter and API calls remain in Jac. `client/session.jac` replaces the contract's retired `session.cl.jac` filename: Jac 0.37.23 rejects the `.cl.jac` marker and infers client placement from the runtime import.

## Automated evidence from this change

| Check | Observed result | Limit |
|---|---|---|
| `node --test tests/ui/*.test.mjs` | 9 passed | Eight real-controller cases with injected camera/API dependencies, plus a real QR render/decode roundtrip; no physical camera or live authentication proof |
| Pinned `jac check main.jac client/session.jac` | 2 passed, existing/style and JS-boundary warnings remain | Compiler/type checking; no browser execution proof |

The roundtrip renders `qrcode.react`'s `QRCodeSVG`, rasterizes its actual SVG paths and decodes the pixels with the installed ZXing `QRCodeReader`. It uses a synthetic credential, not a reusable claim. Run setup/build first so the pinned client dependencies exist.

Controller cases cover canonical payload validation, repeated detections, no mutation before confirmation, denied-camera retry, secure-origin/missing API recovery, cancellation/unmount during pending operations, no mutation from cancelled previews, network failure retries and late-arriving decoder controls.

The coordinator records the integrated production build, backend HTTP tests and any actual browser results separately. These focused checks do not establish the identity, stock or persistence guarantees on their own.

## Engineer 4 compiled UI checkpoint, 2026-09-26

Branch: `feat/04-phone-experience`, based on runtime/QR `bb8fa0f466f6d1cf03ad2423244c21d318ab670c`. The commit containing this section is the tested source checkpoint; obtain its exact revision with `git log -1 -- docs/status/engineer-4.md`.

| Check | Observed result | Limit |
|---|---|---|
| `bash scripts/check.sh` | Exit 0; warnings remain | Whole-program compiler check |
| `bash scripts/build.sh` | Exit 0; 10/10 server modules; `.jab` 1,553,634 bytes | Artifact built, not release-served |
| `node --test tests/ui/browser/phone-dom.test.mjs tests/ui/*.test.mjs tests/tooling/*.test.mjs` | 21 passed, 0 failed | 10 compiled-app DOM cases, 9 QR/controller cases, 2 relay cases; synthetic RPC/camera inputs |
| Independent source review | No remaining blocking findings after fixes | Does not substitute for execution or human review ring |

The DOM cases cover saved card/detail title and price after offer edits, hidden student merchant tabs, unverified entrance-note wording, failed claim retry, failed offer/profile saves with preserved inputs and successful retries, out-of-order filtering, ignored delayed private responses after signout, removal of an already-visible QR on signout, simulated camera denial and an already-expired QR being hidden. Timer crossing the deadline was not tested by that expiry case.

Reproduction and the isolated optional jsdom installation are in `docs/status/engineer-4.md`. No shared dependency manifest changed. An initial DOM invocation overlapped the build and failed because the generated bundle was being replaced; the recorded 21-pass run occurred after the final build completed. The earlier failing snapshot/navigation/note tests were fixed and rerun.

Chromium installation failed with truncated download archives. Consequently there are **no actual browser screenshots, viewport/layout passes or physical camera results** from this run. Linux compiled DOM checks do not verify Mac or phone behavior. The core graph suite and authenticated HTTP acceptance gates remain blocked/unrun as described in Engineer 1/4 status; this frontend increment did not rerun or change backend tests.

## Physical device procedure — not yet executed

Use distinct pre-provisioned student and merchant accounts with privately shared credentials. Keep fixture data labeled demo.

1. Start the documented local app. On a merchant laptop, use the loopback `localhost` page and grant camera access. On the student phone, open the permitted LAN preview and claim an offer.
2. Verify the student sees a large QR plus saved price, terms, eligibility and deadline. Change the offer as the merchant and refresh the student view: the saved claim terms must remain unchanged.
3. Scan the student's screen with the merchant laptop camera. Verify camera capture stops after detection, saved terms appear, and no redemption occurs before **Confirm redemption**.
4. Confirm once. Verify success and the recent-claim status. Scan the same QR again and verify rejection. Scan a claim owned by another restaurant and verify rejection.
5. Deny camera access, retry after allowing it, test a busy/missing camera, cancel while starting, navigate away while scanning, and background the browser. Verify the camera indicator turns off and later callbacks do not resurrect a preview.
6. Interrupt connectivity during claim, preview, confirmation, offer save and profile save. Verify visible errors, preserved form values and usable retry controls. Refresh after uncertain confirmation to inspect the server outcome.
7. Sign out and switch accounts. Verify private QR/merchant data disappears and an earlier pending response cannot refill it. Student accounts must have no merchant controls.
8. Repeat on physical iPhone Safari and Android Chrome. A remote merchant phone camera requires an approved HTTPS origin; the HTTP LAN relay only demonstrates student display, not remote camera access. No new public tunnel is implied.

Record the tested commit, OS/device, browser/version, origin/protocol, account roles, each result and any screenshots without visible reusable QR credentials. Also run the clean-clone Mac procedure in `PHONE-TESTING.md`; a Linux or Windows build is not Mac evidence.

## Open evidence gates

Physical laptop camera scanning, iPhone Safari, Android camera/touch behavior, denied-camera browser settings, and Mac execution remain unverified by this document. No public deployment or physical-phone pass is claimed.

## Windows/WSL continuation, 2026-09-26

Baseline `92987cfea53cfe4f08c159ef775562c20bc2e37b` was fetched and pulled into
the isolated `phone-validation` worktree. Another active checkout and its port
8000 server were preserved. Jac is exactly 0.37.23, on Windows 11 Pro build 26200
with Ubuntu 24.04.3 / WSL2 Linux x86_64.

Baseline reproduction: whole-program check exit 0 with warnings; isolated core
22 passed, exit 0; build exit 0 with 10/10 server modules and a 1,556,863-byte
artifact. The original 21 UI/tooling cases passed. A new confirmed-save/failed-
refresh case failed on the expected false save-failure message. Initial sign-in
focus and already-open sign-in focus regressions also failed before their fixes.
The first synthetic Space test also failed after the button fix: jsdom does not
synthesize native keyboard clicks. It was replaced with a native button/role and
selection check; actual Space behavior is checked separately in the browser.
The DOM harness still uses synthetic RPCs.

The repository's documented Windows dependency fallback was needed because WSL
could not resolve the package registry. npm also omitted the Linux Rollup binary;
installing the exact matching generated dependency `@rollup/rollup-linux-x64-gnu`
4.63.5 with scripts disabled allowed the build. No tracked dependency manifest or
runtime file changed. For faster Windows DOM execution, an isolated matching
`@esbuild/win32-x64` 0.25.12 was used via `ESBUILD_BINARY_PATH`; Linux execution
also reproduced the original 21 passing cases and the new save regression.

### Actual browser observations

Browser: Codex in-app browser on this Windows laptop; engine version not exposed
by the control API. Origin: `http://localhost:8100/`, talking to the real local
Jac API at `127.0.0.1:8101`. Desktop width 1280 and then a verified 390 x 844
viewport were exercised. At 390px, document scroll width was also 390px. This is
desktop viewport evidence, not a physical iPhone or Safari pass.

- Real guest catalog loaded; Under $5 showed the $3 latte and $5 slice. Enter on
  Under $8 loaded the wider catalog and offer details loaded from Jac.
- Space on the focusable Under $8 control did nothing. DOM inspection showed
  focusable controls with no button role. E4 adds button semantics to Pressable
  controls so native Space activation is available.
- Guest Sign in to claim opened the form but left focus on the claim control;
  the email field was partly above the viewport and had no accessible name.
  E4 gives fields accessible names and explicitly focuses an existing email
  input; initial mounting also focuses it.
- An unauthenticated POST to `/function/money` returned 200 and `$1.23` for 1.23.
  The helper is now a plain function, removing an unnecessary public endpoint.

Local baseline screenshots contain only guest/fictional content, with no QR
credentials or account secrets. Raw evidence is ignored under
`.jac/evidence/e4-local/`. Final verification is recorded in Engineer 4 status.

### Team and physical-device gate

E1 received local core evidence and the request to review/integrate E2 PR #3;
E2 received confirmation that E4 owns the money fix and waits for the agreed
context DTO. Both comments are linked from Engineer 4 status. The Windows API
returns the expected 404 for `/graph/data`; E2's reported Mac HTML fallback
requires checking on that host rather than assuming a Windows failure.

Four fictional accounts were provisioned through the documented script. Their
ignored files have protected Windows ACLs for Travis, SYSTEM and Administrators;
WSL mode bits alone did not provide owner-only permissions on this mounted path.
No values are recorded here. Travis has a laptop and iPhone available. A private
hotspot connection was requested before opening the phone preview. Neither that
request nor desktop automation is evidence that a physical test passed.

For the separate port, the documented underlying runtime command is used after
`source scripts/runtime.sh` and `source .jac/qr-demo.env`:

```bash
"$JAC_BIN" run --dev --host 127.0.0.1 --port 8100 --api-port 8101
```

Stop that dev process before rebuilding. The existing port 8000 process is not
part of this worktree and must not be stopped as part of these checks.

### Final source and automated verification

Frontend source commit: `5ea1d967bf2115a5b7c9d6f2474a29e482c782f5`.
Changes stay in `main.jac`, `theme.jac` and `tests/ui/browser/**`.

| Check | Result | Scope |
|---|---|---|
| `bash scripts/check.sh` | Exit 0; 1 compiler check passed in 108.35s; warnings remain | Stable final Jac source |
| `bash scripts/build.sh` | Exit 0; 10/10 server modules; 1,552,552-byte `.jab` | Built artifact, not production serving |
| UI/tooling suite, independently executed | 25 passed, 0 failed, 0 skipped; exit 0 | 14 compiled DOM, 9 QR/controller, 2 relay cases |
| Independent source review | No remaining blocking findings | Does not replace required human/Baz review |

The new DOM cases verify truthful save confirmation after a failed follow-up
refresh, native budget-button semantics and selection, and sign-in focus for
both newly mounted and already-open forms. Earlier failed test output is kept
locally alongside the passing run. A build interrupted by a source change was
discarded; the successful build above ran on stable source.

Local logs: `check-stable.log`, `build-stable.log`, `ui-final-verified.log` and
the independent UI exit-code file in `.jac/evidence/e4-local/`. Core 22/22 was
reproduced against starting commit `92987cf`; backend files did not change in
this frontend increment. Authenticated HTTP and physical-camera results must
be recorded separately from these passing checks.

### Live verification at the final source

Observed 2026-09-26, approximately 19:09-19:12 America/New_York, on the Windows
laptop and Codex in-app browser described above. Source is `5ea1d967bf2115a5b7c9d6f2474a29e482c782f5`;
origin is `http://localhost:8100/`, real API `http://localhost:8101/`.

- Space on Under $5 returned two offers; Space on Under $8 returned four.
  The controls now appear as buttons in the accessibility tree.
- Space on guest Sign in to claim mounted the form and focused the named Email
  input. Activating the claim control again with Enter refocused the existing
  form. No real account secrets were entered during browser capture.
- At 390 x 844 and 320 x 740, document scroll width equaled viewport width.
  Sign-in controls and the focused email field were visible. This does not test
  an iOS keyboard, touch scrolling, Safari, or a physical phone.
- Browser warning/error collection returned no entries during this final pass.
  Initial pre-ready navigation failed; a fresh tab was used after the server
  became ready. Preparation was slow on the Windows-mounted WSL checkout.
- Unauthenticated POST `/function/money` with `{v:1.23}` returned **405**;
  the earlier exposed price formatter is no longer callable by POST.

Credential-free screenshots:

- [Guest catalog, 390px](../tests/ui/evidence/2026-09-26-e4/catalog-390.png)
- [Sign-in focus, 390px](../tests/ui/evidence/2026-09-26-e4/signin-390.png)

Independent real HTTP execution used the unchanged command:

```bash
python3 tests/integration/qr_http.py --api http://localhost:8101
```

Result: **exit 1**, graph-inspector gate passes (404), trusted merchant membership
fails. One named check passed, one failed, 21 later named checks were unreached;
no dedicated offer was created. A separate authenticated role probe confirmed
both students are students and both provisioned merchants incorrectly return
student. No credentials, tokens, root IDs or reusable QR payloads were printed.
Raw logs are `qr-http-final.log`, `role-probe-final.log` and
`money-endpoint-final.log` under the ignored evidence directory.

This does not validate claim ACLs, concurrency, redemption, saved terms over
HTTP, or QR restart persistence. E1 must integrate the reviewed E2 fix before
the real merchant camera sequence can proceed. Laptop guest browsing is ready.
At this earlier checkpoint, the phone relay awaited the hotspot connection;
the subsequent limited physical-device result is recorded below. No public
tunnel or venue-network exposure was opened.

### User-reported iPhone browsing, 2026-09-26

Tested checkout: `a02ce148a96402694ae4aa79023fe1d99d855cda` (frontend implementation
unchanged from `5ea1d967bf2115a5b7c9d6f2474a29e482c782f5`). Origin supplied to
Travis: `http://172.20.10.5:8081/`, bound only to the laptop's iPhone-hotspot
interface and relayed to the app at `http://localhost:8100/`.

At 19:20 America/New_York the laptop-side relay check returned 200 for the page
and the guest Jac session API. No Windows firewall settings were changed.
Travis then reported: "i can verify that it works on mobile". Record this as
**user-reported basic physical iPhone browsing success**. The requested sequence
was Under $5 -> $3 oat latte -> Sign in to claim; individual actions, keyboard
visibility and rotation were not separately confirmed. Travis subsequently
reported the device/browser as **iPhone 18 Pro, Safari, v27.0**. Preserve that
reported version as supplied; an iOS version was not separately specified.

No login, real QR claim, physical scan, redemption, camera permission recovery,
wrong-merchant rejection or expiry pass is established by this report. HTTP
student-phone browsing does not verify merchant-phone camera operation. No
device screenshot or credential was collected. The local guide and relay smoke
record remain ignored under `.jac/evidence/e4-local/`.
