# Release Checklist

Status: not release-ready. Unverified items remain explicitly open.

- [x] Jac 0.37.23 pinned and checksum-verified.
- [x] Runtime resolver rejects mismatched binaries.
- [x] Source check passes.
- [x] Core tests pass: 3 passed, 2 skipped.
- [x] Production `.jab` build passes.
- [x] Isolated demo server returns HTTP 200.
- [x] UI/tooling checks pass: 11 passed.
- [x] Aggregate command propagates missing-suite/account failures.
- [ ] Context suite available and passing.
- [ ] Provision local demo accounts and run `tests/integration/qr_http.py`.
- [ ] Verify restart persistence with the same store.
- [ ] Verify simultaneous last-unit claims and redemptions over HTTP.
- [ ] Separate users share the public catalog without private QR credentials.
- [ ] Second teammate reproduces setup from a clean clone.
- [ ] iPhone Safari and Android camera flow verified on a supported secure origin.
- [ ] Baz review and source-language inventory completed.
- [ ] Organizer deadline confirmed and demo evidence recorded.
- [ ] Deployment decision authorized by the human team.

No credentials, passwords, or private account files belong in Git.
