# Engineer 4 — frontend / phone handoff

Updated 2026-09-26. Travis confirmed he is Engineer 4. The latest explicit agent-team authorization permits bounded, file-disjoint agents and an independent verifier; it does not transfer other humans' file ownership.

## Branch and ownership

- Continue `feat/04-phone-experience`, based on runtime/QR commit `bb8fa0f466f6d1cf03ad2423244c21d318ab670c` in draft PR #1.
- Engineer 1 owns main merges. The frontend PR is stacked on `feat/01-runtime-release` to keep the review small; retarget after the runtime PR lands.
- This increment changes only `main.jac`, `tests/ui/browser/**`, this status file and `docs/phone-validation.md`. Backend, data, runtime configuration and dependency manifests are unchanged.
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
node --test tests/ui/browser/phone-dom.test.mjs tests/ui/*.test.mjs tests/tooling/*.test.mjs
```

Wait for the build to finish before running DOM tests: the build replaces `.jac/client/dist`. The harness reads the actual generated bundle. `MLOCAL_UI_TEST_MODULES` can point to another isolated `node_modules` directory containing jsdom.

## Evidence and limits

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
