# Engineer 2 status: trusted offer transactions

Branches: `feat/02-qr-fixes` (merged, PR #3) and `feat/02-access-context` (on main).
Runtime: Jac 0.37.23 (Apple Silicon Mac, official binary, checksum verified).

## What happened

The runtime branch already contains a backend for the Engineer 2 mission (QR
credentials, server-derived identity, claim snapshots, `resolve_claim` /
`redeem_claim`). Rather than ship a second backend, this branch keeps that
design and fixes what a real Mac run of it found. The earlier standalone
Engineer 2 implementation stays on `feat/02-offer-trust` as timestamped
reference; its proven lock pattern and HTTP suite are what this branch ports.

## Bugs found and fixed (with evidence)

1. **No account could ever become a merchant.** `scripts/provision-demo.py`
   writes hyphenated UUIDs into `MLOCAL_MERCHANT_OWNERS`; `jid(root)` on
   0.37.23 is the 32-hex form; `configured_owners` insisted on the hyphenated
   spelling. Result: `merchant_leaf` logged in as a student and the whole
   redemption flow was unreachable. Fix: `qr_auth.jac` canonicalizes either
   spelling to `UUID(actor).hex`. Test updated.
2. **Simultaneous requests oversold stock.** With the default worker count,
   20 simultaneous claims on a one-unit offer produced 5 winners, and 10
   retries by one student created 3 claims. The runtime's transactions did not
   prevent it. Fix: every mutating endpoint holds an exclusive OS file lock,
   refreshes its transaction after locking, and commits before unlocking
   (`_lock` / `_unlock` in `promo.jac`). Safe on one machine only.

## Evidence at this commit

- `bash scripts/check.sh`: exit 0. `bash scripts/test.sh core`: 22 passed.
- `tests/integration/qr_race_http.py` (starts its own API-only server,
  registers fresh accounts each run, provisions merchants the way
  `provision-demo.py` does): **37/37 on three runs** (two with default workers,
  one with `--workers 1`). Covers 401s for guests, merchant recognition,
  private credentials, wrong-merchant rejection, stable terms after an edit,
  preview without mutation, double redemption, 5 simultaneous scans of one QR
  (redeemed once), 20 simultaneous last-unit claims (one winner), 10
  simultaneous retries (one claim), cancel, and restart persistence.

## Context attached (Engineer 4 can render now)

`OfferView.access_context: AccessContextView` is populated in `_view` from
`get_access_context(location_id, now)` with the server clock; `location_id`
is the Location node id. Every `list_offers` / `get_offer` result carries it.
Verified: the seeded demo notice appears only on the Noodle Lab offers, other
restaurants report `none`, and a stale clock yields `needs_recheck` with no
entrance instruction. Shape:

```text
AccessContextView { state: "current" | "needs_recheck" | "none",
                    notices: list[AccessNoticeView] }
AccessNoticeView  { id, summary, publisher, source_url, checked_at, valid_from,
                    valid_until, state ("current" | "needs_recheck"), is_demo,
                    entrance_instruction }
```

Render rule from the contract: `none` is not an all-clear; only a `current`
notice may show `entrance_instruction` as definitive.

## Notes for other owners

- Engineer 1: `tests/integration/qr_http.py` fails on Mac at its first line
  because `/graph/data` returns the app HTML (200), not 401/403/404; the graph
  inspector is disabled, so nothing leaks, but the check needs loosening.
  `theme.jac` declares `def:pub money`, which the placement solver serves as a
  public endpoint `/function/money`; harmless but should be a plain `def`
  (Engineer 4's file).
- Engineer 3: context integrated on main; nothing pending from Engineer 2.
