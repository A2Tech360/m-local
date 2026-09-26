# Engineer 1 Status

Branch: `feat/01-runtime-release`

## Verified

- Jac 0.37.23 is pinned and checksum-verified on macOS arm64.
- `bash scripts/check.sh` passes.
- `bash scripts/test.sh core` passes: 3 passed, 2 skipped.
- `bash scripts/build.sh` produces `dist/mobile-starter.jab`.
- `scripts/demo.sh` starts an isolated server and returned HTTP 200.
- UI/tooling integration checks pass: 11 passed.
- Runtime mismatch and missing-account failures are explicit and nonzero.
- PR #3 latest head `fd62ab4` is integrated by merge commit `792cdb0`.
- The clean-source seed repair removes an import to an absent context module.
- Endpoint discovery now exposes all required offer/session/QR functions.
- Real QR HTTP acceptance passed all assertions on an isolated provisioned server.
- Core coverage now passes 22 tests with no skipped modules.

## Outstanding

- Context tests are not present in this checkout.
- QR HTTP acceptance requires private provisioned local accounts and a running server.
- Restart/database concurrency evidence is not verified here.
- Physical phone camera flow, second-machine setup, Baz review, deadline, and deployment authorization remain open.

No public write-enabled pilot is approved.
