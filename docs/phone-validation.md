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
