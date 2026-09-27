# Runtime Verification

## Selected runtime

- Jac: `0.37.23`
- Platform verified here: macOS arm64
- Pin: `.jac-version`
- Runtime location: `~/.local/share/m-local/runtimes/0.37.23/jac`
- Client build: Bun 1.3.11, Vite 6.4.3, React 18.3.1, react-native-web 0.19.13
- Persistence/runtime support: Jac embedded PostgreSQL on the runtime branch

The runtime was installed by `bash scripts/setup.sh`. Both the `jac` and
`jacpython` release assets were checksum-verified. The repository scripts reject
a missing or mismatched Jac binary.

## Commands verified

```bash
bash scripts/setup.sh
bash scripts/check.sh
bash scripts/test.sh core
bash scripts/build.sh
MLOCAL_PORT=8127 bash scripts/demo.sh
bash scripts/test.sh integration
bash scripts/test.sh all
```

Observed results:

- `check.sh`: pass.
- `test.sh core`: 3 passed, 2 skipped.
- `build.sh`: pass; produced `dist/mobile-starter.jab`.
- `demo.sh`: pass; isolated server returned HTTP 200 on port 8127.
- UI/tooling integration checks: 11 passed.
- `test.sh integration`: intentionally nonzero when `.jac/qr-demo-accounts.json` is absent.
- `test.sh all`: intentionally nonzero because context tests and provisioned QR HTTP tests are not available in this checkout.

`dev.sh` uses `jac run --dev --host 127.0.0.1 --port 8000` for Jac 0.37.23.
`demo.sh` uses a temporary copied workspace and a dedicated `MLOCAL_PORT`.

## Authentication and integration gates

The Jac runtime authentication API is documented in the bundled
`jac-sv-auth` guide: register with `identities` and `credential`, then login
with `identity` and `credential`; authenticated functions receive the caller's
root implicitly. `scripts/provision-demo.py` creates private local accounts and
a server-only merchant ownership map without printing credentials.

Not yet verified here:

- two-user authenticated QR HTTP acceptance with a provisioned local store;
- restart persistence and simultaneous database claims/redemptions;
- physical iPhone/Android camera flow and secure-origin camera behavior;
- a separate teammate clean-clone run;
- Baz review, event deadline confirmation, and deployment authorization.

No public write-enabled pilot is authorized by this document.

Python tests that import Jac services must use the pinned companion interpreter:
`bash scripts/test.sh onboarding` or `bash scripts/python.sh tests/integration/onboarding_http.py`.
The latter fixture requires its documented isolated local server and store; it must not target production.
Plain system Python does not register Jac imports. `scripts/setup.sh` installs both executables together.
