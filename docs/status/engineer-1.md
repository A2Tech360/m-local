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
- PR #3 was merged as `068caf7` and pushed to this branch.
- Real QR HTTP acceptance reached the merged server but stopped at
	`current_session: unexpected HTTP 405`; the live `/functions` endpoint exposed
	only `money`. This is an Engineer 4 application-wiring issue, not a runtime
	installer failure, and was not changed by Engineer 1.

## Outstanding

- Context tests are not present in this checkout.
- QR HTTP acceptance requires private provisioned local accounts and a running server.
- Restart/database concurrency evidence is not verified here.
- Physical phone camera flow, second-machine setup, Baz review, deadline, and deployment authorization remain open.

No public write-enabled pilot is approved.
