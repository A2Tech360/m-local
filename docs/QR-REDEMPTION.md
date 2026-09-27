# QR redemption: local setup and acceptance

This increment replaces manual claim-code entry with student QR display and a
merchant camera scan, a server preview, then explicit confirmation. Jac owns the
claim, saved terms, expiry, merchant authorization and redemption mutation. The
wire format is frozen in [TEAM-CONTRACT](TEAM-CONTRACT.md#frozen-qr-wire-contract-2026-09-26).

## Run the branch

Use Jac **0.37.23**, the scripts in [RUNTIME](RUNTIME.md), and the latest
`feat/01-runtime-release` commit. Stop dev before building. This change replaces
the old demo student-name and merchant-key selectors with Jac login. It does not
verify university enrollment; the merchant checks the stated ID requirement.

Start the server once, then in another local WSL/Linux/Mac terminal:

```bash
python3 scripts/provision-demo.py --api http://localhost:8001
```

The script creates four fictional test accounts using Jac's built-in auth API.
Credentials are saved only in ignored `.jac/qr-demo-accounts.json` with owner-only
permissions. Keep that file private. Do not commit it or paste its contents into
reports. The script refuses to overwrite an existing account file. It also writes
`.jac/qr-demo.env`, a server ownership map for the Arbor Leaf and Noodle Lab demo
restaurants. The map contains root UUIDs, not passwords or tokens.

Stop the dev server, then restart from the same terminal after loading the map:

```bash
source .jac/qr-demo.env
bash scripts/dev.sh
```

Use the private account file to sign in as `student_a` in one browser and
`merchant_leaf` in another. Different browser profiles or a private window keep
their sessions separate. An unconfigured merchant account has student access;
there is no UI control that grants merchant ownership.

Existing six-character claims are historical data. Their codes are not valid QR
credentials. Preserve the prior store as evidence; do not erase it to manufacture
a clean migration or a new test pass. Pre-existing offers stay closed to new QR
claims until a trusted reconciliation is implemented. For the QR demo, sign in as
the provisioned merchant and create a new fictional offer. Freshly seeded offers
in a genuinely new store also support QR. This conservative boundary prevents
private legacy redemptions from accidentally reopening consumed stock.

## Automated checks

```bash
bash scripts/check.sh
bash scripts/test.sh core
node --test tests/ui/*.test.mjs tests/tooling/*.test.mjs
bash scripts/build.sh
```

The UI controller tests exercise duplicate detections, permission failure,
cancellation and async cleanup through controlled browser dependencies. They do
not prove an actual camera can read the rendered QR.

After local account provisioning and restart with the ownership map, this
separate, opt-in test calls the real Jac HTTP endpoints:

```bash
python3 tests/integration/qr_http.py --api http://localhost:8001
```

It creates a dedicated fictional one-unit offer, checks a shared catalog across
two authenticated roots, attempts simultaneous claims, checks private credential
visibility and merchant ownership, previews without mutation, edits future terms,
and attempts simultaneous and repeated redemption. It leaves its clearly named
test offer in the local store for diagnosis. It never resets existing data or
prints credentials. A test script existing in Git is not a passing result.

## Physical two-device check

1. Student signs in on a phone, claims an offer and displays its QR and saved terms.
2. Merchant signs in on a laptop at `localhost`, starts the camera, scans the QR,
   verifies the preview and confirms redemption.
3. Scan again: redemption must be refused. Deny the camera, then re-enable and
   retry; cancel a scan and verify the camera indicator turns off.
4. Reload the student view. Restart the server with the same store and map; the
   redemption must remain redeemed.
5. Repeat display/taps on iPhone Safari and Android Chrome; repeat the documented
   setup on the Mac teammate's computer. Record commit, OS, browser and result.

Student QR display can use the HTTP LAN relay. A remote merchant-phone camera
requires HTTPS; HTTP LAN browsing is not camera evidence. No public tunnel or
hosted deployment is included in this increment.

## Evidence boundaries

See [Engineer 1 status](status/engineer-1.md) for actual commands and results.
Cloud execution currently cannot start embedded PostgreSQL: the root-only UID
namespace rejects the runtime's attempt to hand the directory to `nobody`.
Consequently authenticated HTTP, durable restart, and concurrent database checks
must be recorded on a supported teammate host before making those guarantees.
Compiler/build and controller tests are separate evidence.

The historical Windows tests exercised the old code-entry flow. They are not QR
passes. Mac, physical phone cameras, release-artifact serving, Baz review and the
organizer's event-time eligibility check remain explicit team gates. The original
source provenance has not changed.
