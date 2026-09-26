# Engineer 1: Runtime, Integration and Release Implementation Plan

> **For agentic workers:** The execution method is four human engineers using their
> own models. Implement only this mission. Use `superpowers:executing-plans` if
> available; otherwise follow the same inspect, test, implement, verify loop.
> Do not spawn agents or launch the other missions without your human's instruction.

**Goal:** Make a clean checkout run reproducibly and prove the integrated product.

**Architecture:** Keep the existing Jac application. Pin a compatible runtime,
provide one set of local commands, and exercise the real HTTP/UI boundary with
isolated graph stores. Integrate the other owners' PRs rather than rewriting them.

**Tech stack:** Jac/MobUI, Bash on WSL, GitHub, minimal test tooling supported by the runtime.

**Spec:** [Mission](../../START-HERE.md), [contract](../../TEAM-CONTRACT.md),
[workflow](../../TEAM-WORKFLOW.md).

## Global constraints

- Branch: `feat/01-runtime-release`; keep application logic in Jac.
- No real business contacts, spending, secret commits or unapproved deployment.
- One agreed runtime; do not overwrite the existing independent WSL lab runtime.
- Preserve original source commit `715b4ba` and source provenance.
- No public write-enabled pilot without verified identity/ownership.

## Files and ownership

Modify `jac.toml`, `README.md`, `AGENTS.md`, `TEAM-HANDOFF.md`, `.gitignore` as needed.
Create `docs/RUNTIME.md`, `scripts/dev.sh`, `scripts/check.sh`, `scripts/test.sh`,
`scripts/demo.sh`, `tests/integration/test_acceptance.py`, `docs/RELEASE-CHECKLIST.md`
and `docs/status/engineer-1.md`. Add a runtime/version file and a minimal CI workflow
only after local commands work. You own root configuration and integration tooling.
Do not edit `main.jac`, `theme.jac` or `services/*.jac`; send compatibility failures
to their owners with exact diagnostics. Never reset a shared graph database.

## Interfaces

Produce the six stable commands in TEAM-CONTRACT, a version pin, and verified
client/server authentication imports. `test.sh` accepts core/context/integration/all
and returns nonzero on failures. Consume Engineers 2/3's server behavior and
Engineer 4's UI. No command may quietly replace failures with fixture success.

## Review focus

1. New machine with no dependencies: setup gives actionable errors and the verified pin.
2. Paths with spaces on Windows/WSL: launch/test commands preserve the intended paths.
3. Tests run twice or concurrently: stores/ports stay isolated and user data survives.
4. Authenticated roots differ: two users still see the intended shared public catalog.
5. A server restart or concurrent request: HTTP results match durable stored state.

## Work sequence

### 1. Publish the runtime checkpoint

- [ ] Inspect the baseline, repository instructions, runtime help and bundled Jac guides.
- [ ] Try the generated 0.34.20 runtime in an isolated project environment. If it cannot
  be reproduced, propose one specific supported version with the failing evidence.
  Avoid an open-ended migration; have the humans agree before all owners target it.
- [ ] Start the actual app locally. Record exact shell commands and versions, including
  client tooling, in `docs/RUNTIME.md`. Distinguish compilation/startup from flow tests.
- [ ] Verify built-in authentication helpers and server principal access with two local
  accounts and document exact import paths. Probe shared/private graph scope. Route
  production source changes to Engineer 2 or 4.
- [ ] Commit the smallest usable runtime/configuration change and open the first PR.
  Announce the pin and commands to the human team; this unblocks runtime-dependent work.

### 2. Make commands reproducible

- [ ] Implement the stable scripts. `dev.sh` defaults to 127.0.0.1:8000. Test/demo scripts
  use dedicated stores and free ports. Record the runtime-supported isolation mechanism.
- [ ] Add checks named `test_setup_path_with_spaces`, `test_test_store_isolation`,
  and `test_missing_runtime_is_actionable`; demonstrate each fails against the initial
  scripts before implementing its fix. Use temporary test data, never personal stores.
- [ ] Make `demo.sh` create a fresh fixture store on every invocation, using Engineer
  3's seed data and Engineer 2's supported demo-account provisioning. Do not delete
  another store or print account credentials into committed evidence.
- [ ] Run `./scripts/check.sh` and `./scripts/test.sh all`. Before downstream tests
  exist, report their status as missing; do not mark the full suite passing.
- [ ] Have another human teammate run the documented setup from a separate clone.
  Record their result, OS, pin and commit, with permission to include that evidence.

### 3. Test the integrated behavior and prepare release

- [ ] Add `test_restart_preserves_claim_and_redemption`: create a $8 offer and claim,
  restart the service with the same isolated store, verify the same code and $8 terms,
  redeem, restart again, and verify the redemption remains consumed.
- [ ] Add `test_last_unit_two_sessions`: submit two simultaneous HTTP claims from
  distinct student accounts to quantity 1; exactly one reservation may succeed.
- [ ] Add `test_retry_preserves_code`: interrupt/retry the same student's request and
  verify one claim/code, with no extra stock consumption.
- [ ] Add `test_public_catalog_private_claims`: separate student accounts see the same
  offer but not each other's codes; a guest cannot mutate; merchant A cannot edit B.
- [ ] Run `./scripts/test.sh integration` against the merged implementation. Attach
  failing cases to the owning engineer rather than changing their modules yourself.
- [ ] Coordinate one iPhone Safari run with Engineer 4. Choose a reachable URL with
  the humans; WSL localhost is not automatically reachable from an iPhone. Confirm
  that the entire flow, not only the initial page, works at that URL.
- [ ] Create the release checklist: commit, runtime, build/test evidence, language
  inventory methodology, Baz review/result, fixture/source labels, video outline,
  deployment decision and organizer-confirmed deadline. Mark outstanding items honestly.
- [ ] Commit, open/update your PR and summarize the final integrated state. Hosting and
  external submissions remain human-authorized actions, not automatic finishing steps.

## Done when

A teammate can reproduce setup; core/context/integration checks pass on the chosen
runtime; the phone flow has actual evidence; required review/submission gaps are
visible. Do not claim release readiness if any required check is still unrun.

## Starting prompt

```text
You are Engineer 1, runtime and integration owner for M-Local.
Repository: https://github.com/CosmonautJones/m-local
Read AGENTS.md, docs/START-HERE.md, docs/TEAM-CONTRACT.md,
docs/TEAM-WORKFLOW.md, and your plan:
docs/superpowers/plans/2026-09-26-01-runtime-release.md.
Implement only this mission on feat/01-runtime-release in my own clone.
The exported app is not yet locally verified. Its README reports Jac 0.34.20;
the separate 0.37.21 lab removed jac start. Prove and pin a compatible runtime
before telling the other humans to upgrade. Verify actual MobUI and auth hooks.
Own configuration, scripts, integration tests and release evidence. Do not edit
main.jac, theme.jac or another engineer's service files. Route source failures
to the human owner with a reproducer. Publish small PRs, beginning with the pin.
Build the exact script interfaces in the contract, isolate test/demo stores,
and prove cross-session claims and restart persistence over the real server.
Keep Jac central, preserve provenance, and never commit secrets. No business
contacts, purchases, deployments, invitations or new agent teams. State what
passed, failed or was not run. End with commit/PR, exact commands, evidence,
remaining blockers, and an update to docs/status/engineer-1.md.
```
