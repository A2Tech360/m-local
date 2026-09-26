# Engineer 4 — frontend / phone handoff

Updated 2026-09-26. Travis confirmed he is Engineer 4. The latest explicit agent-team authorization permits bounded, file-disjoint agents and an independent verifier; it does not transfer other humans' file ownership.

## Branch and ownership

- Continue `feat/04-phone-experience`, based on runtime/QR commit `bb8fa0f466f6d1cf03ad2423244c21d318ab670c` in draft PR #1.
- Engineer 1 owns main merges. The frontend PR is stacked on `feat/01-runtime-release` to keep the review small; retarget after the runtime PR lands.
- E4 changes stay in `main.jac`, `theme.jac`, `tests/ui/**`, this status file and `docs/phone-validation.md`. Backend, data, runtime configuration and dependency manifests are unchanged.
- The published Engineer 3 branch is `feat/03-local-context` at `0e5a6dafa18d4ed1256f1a297bc15631ccd8f4aa`. It is not integrated here. Do not overwrite teammates' work.

## What this increment changes

- Offer cards and details lead with saved title and integer-cent price for held/redeemed claims, excluding edited descriptions, savings and current terms from the saved-claim detail.
- Students/guests no longer see merchant navigation controls. The existing Jac server remains the authorization authority.
- Legacy entrance notes are explicitly unverified restaurant reports, with a provided date rather than a claim of verification.
- A compiled-app DOM harness exercises real generated Jac/MobUI/React UI code with explicitly synthetic RPC responses. It is not a backend substitute.

## Reproduction

Use the documented Jac **0.37.23** setup/check/build scripts first. The optional DOM harness needs Node 20.11+ and an isolated jsdom installation. Engineer 1 still owns approval of any permanent shared test dependency; none was added to project manifests.

```bash
bash scripts/check.sh
bash scripts/build.sh
npm install --prefix .jac/ui-test-runtime --no-save --no-package-lock --ignore-scripts --no-audit --no-fund jsdom@26.1.0
node --test tests/ui/browser/*.test.mjs tests/ui/*.test.mjs tests/tooling/*.test.mjs
```

Wait for the build to finish before running DOM tests: the build replaces `.jac/client/dist`. The harness reads the actual generated bundle. `MLOCAL_UI_TEST_MODULES` can point to another isolated `node_modules` directory containing jsdom.

## Evidence and limits

This section records the earlier cloud checkpoint. The Windows/WSL continuation
and final results below add later evidence without converting that failed core
run into a pass.

Final check/build/DOM outcomes are recorded in `docs/phone-validation.md`. Source changes received independent agent review. Findings about card snapshots and insufficient retry/signout assertions were addressed before handoff.

Earlier runtime/QR evidence at `bb8fa0f`: whole-program checking and production build passed; 7 focused Jac checks and 11 UI/tooling checks passed. Full core run: **12 passed, 10 errors before assertions** because embedded PostgreSQL cannot change ownership/drop privileges under this cloud runner's UID mapping (`Errno 22`). Do not label this a passing core suite. Real authenticated HTTP, ACL behavior, concurrency and QR restart persistence remain unrun here.

Chromium download failed with truncated archives, so no real browser layout, screenshot, physical camera, phone or Mac pass is claimed. DOM camera-denial injection and pixel-level QR decoding are narrower checks. No public deployment/tunnel was opened.

## Next bounded work in Codex

1. Fetch remote state, inspect any newer commits and preserve unpublished local work. Read `docs/WORK-HANDOFF.md` first, then `AGENTS.md`, runtime/phone docs, contract v2, workflow and the Engineer 4 plan.
2. On a supported local host, coordinate with E1/E2 to run the documented isolated core suite and `tests/integration/qr_http.py`; use private provisioned accounts and new fictional QR-ready offers. Old offers are intentionally closed pending trusted reconciliation. Do not paste account files or reusable QR credentials into logs.
3. Run the actual app in a browser, then laptop localhost camera -> student LAN display. A merchant phone camera needs approved HTTPS; HTTP phone browsing is not a camera test. Record denial/retry, duplicate scans, explicit confirmation, wrong merchant, expiry and repeat redemption.
4. Continue the E4 plan's keyboard/viewport/loading/error work, preserving snapshot and session privacy behavior. Capture real screenshots without reusable credentials. Physical iPhone Safari, Android and Mac execution need actual evidence.
5. Wait for E2 to expose E3's `location_id` / `access_context` on OfferView, then render the agreed none/current/needs_recheck states with source, publisher, checked/valid dates and demo label. Do not invent a replacement DTO or edit another lane's production files.
6. Keep Baz review, competition-time provenance and organizer-confirmed event/rule evidence as separate team gates. Do not claim a full MVP from this checkpoint.

## Local continuation plan, 2026-09-26

Starting source: `92987cfea53cfe4f08c159ef775562c20bc2e37b`. Use a managed
`phone-validation` worktree because another active chat shares the original
checkout. Preserve that checkout and its running server. Continue the existing
E4 branch and stacked PR #2; E1 remains the integrator.

- [x] Fetch remote state and read the current handoffs. PR #3 at `5cbb709`
  contains E2's merchant UUID and concurrent mutation fixes, not integrated here.
- [x] Reproduce the whole-program check and isolated core suite on Windows/WSL.
  Check exit 0 (warnings remain); core 22 passed, exit 0. This does not prove HTTP
  authorization or concurrency.
- [x] Build and reproduce the compiled UI/tooling checks before frontend edits.
- [x] Exercise this exact app in a real browser on a separate local port. Record
  keyboard/narrow viewport/recovery observations before choosing UI changes.
- [x] Add a regression for a confirmed offer save followed by a failed list
  refresh; fix truthful recovery only in E4 files. Check E2's money RPC finding.
- [x] Verify the final source independently, update E4 evidence, and publish the
  small checkpoint to PR #2 without merging other lanes.

Delegation: one agent reproduces core checks without tracked edits; one audits
UI and owns only the added regression in `tests/ui/browser/phone-dom.test.mjs`;
the coordinator owns production E4 files and documentation. A separate verifier
reviews the final diff and reruns focused checks. No backend/runtime/data edits.

Travis confirmed access to a laptop and iPhone. Device results remain pending
until actually performed. The existing runtime at port 8000 belongs to a different
checkout; it is not E4 evidence.

Coordination consisted of comments on [E1 PR #1](https://github.com/CosmonautJones/m-local/pull/1#issuecomment-5850445297)
and [E2 PR #3](https://github.com/CosmonautJones/m-local/pull/3#issuecomment-5850459996).
The merchant-recognition fix is needed for real merchant acceptance. The location/
access DTO reminder is later context work, not a prerequisite for phone browsing.

For Windows DOM execution against this WSL-generated bundle, install the matching
optional test binary only in the ignored test runtime (PowerShell):

```powershell
npm.cmd install --prefix .jac/ui-test-runtime --no-save --no-package-lock --ignore-scripts --no-audit --no-fund jsdom@26.1.0 @esbuild/win32-x64@0.25.12
$env:ESBUILD_BINARY_PATH = (Resolve-Path .jac/ui-test-runtime/node_modules/@esbuild/win32-x64/esbuild.exe).Path
node --test tests/ui/browser/*.test.mjs tests/ui/*.test.mjs tests/tooling/*.test.mjs
```

### Final local checkpoint

Source `5ea1d967bf2115a5b7c9d6f2474a29e482c782f5`: stable-source check/build pass;
independent UI/tooling suite 25/25; independent source review has no remaining
blocking findings. Real browser Space activation and sign-in focus were verified
at `http://localhost:8100/`; 390px and 320px viewports had no document overflow.
Screenshots and detailed environment/result limits are in `docs/phone-validation.md`.

Real authenticated HTTP acceptance **fails** at merchant membership: both
provisioned merchant accounts return `student`. Graph inspector privacy passes
with 404; later claim/concurrency/redemption checks were not reached. This is
consistent with the E2 PR #3 fix that E1 has not integrated into this branch.
The unauthenticated money POST now returns 405. No backend ownership workaround
was applied. Physical iPhone/webcam acceptance, Mac, artifact serving, human/Baz
review and organizer-confirmed rules remain open gates.

### Jac architecture audit requested by Travis

At source `5ea1d96`, the UI and session adapter are Jac. The server defines real
Restaurant, Location, MenuItem, Offer, Redemption and Reservation nodes with
typed edges in `services/models.jac`. `services/promo.jac` traverses those edges
for discovery and attaches claim/reservation nodes for durable state. The
frontend consumes Jac responses; QR camera/encoding interop does not own offer
terms, identity or redemption decisions.

There are currently **no walker declarations or spawn/visit flows** in the E4
branch's Jac sources. Graph traversal is inside ordinary Jac functions. E3's
unintegrated context helper also uses function-based graph queries. These facts
must not be presented as proof of a walker-driven implementation. Jac 0.37.23's
bundled `jac-walker-patterns` guide describes the distinct walker model.

Explicit walker use is an architecture review point for E2, with E3 involved for
access-context traversal. E4 keeps the agreed OfferView boundary and does not
rewrite backend files or invent a replacement DTO to add it. Competition rule
compliance and any Jac-percentage claim still need their separate evidence.
