# PromoPusher (prototype)

**Hackathon team: [start here](docs/START-HERE.md).** The mission, impact goals,
four engineering assignments and copy-ready model prompts are documented there.
Read the [shared contract](docs/TEAM-CONTRACT.md) and
[parallel workflow](docs/TEAM-WORKFLOW.md) before implementing. These are planned
changes; the generated setup notes below still need the runtime verification owned
by Engineer 1.

Mobile-friendly Ann Arbor app connecting students with time-limited restaurant offers.
One Jac source compiles to web (react-native-web) and React Native (MobUI).

## Versions (recorded 2026-09-26)

| Component | Version |
|---|---|
| Jac (jaclang) | 0.34.20 |
| Python (server runtime) | 3.12.14 |
| Node.js / npm | 22.23.3 / 10.9.9 |
| react / react-dom | ^18.2.0 |
| react-native-web | ^0.19.13 |

No other dependencies. Persistence is the built-in Jac graph store (`.jac/data`, SQLite).

## Setup

```bash
jac install                 # installs npm deps from jac.toml
jac start --dev main.jac    # web preview at http://localhost:8000
jac start main.jac --client react-native --dev   # native (after `jac setup react-native`)
```

Demo data seeds itself the first time any endpoint runs. To reset: `jac clean --data --force`.

## Layout

| File | Role |
|---|---|
| `services/models.jac` | Graph schema: Restaurant, Location, MenuItem, Offer, Redemption + edges |
| `services/promo.jac` | Business rules and `def:pub` API (all enforcement is here) |
| `services/importer.jac` | `import_restaurant(record)`: the single data-import boundary |
| `services/seed.jac` | Three fictional "(Demo)" businesses and labeled demo offers |
| `services/promo.test.jac` | Rule checks |
| `theme.jac` | Design tokens and StyleSheet |
| `main.jac` | Entire MobUI interface (4 screens + tab bar) |

Graph: `Restaurant -HasLocation-> Location`, `-Serves-> MenuItem`, `-Publishes-> Offer -Features-> MenuItem`, `Offer -ClaimedAs-> Redemption`.

## Rules (server-enforced)

- **Roles.** Students identify by name/ID; merchants by a per-restaurant merchant key
  (`noodle-demo`, `leaf-demo`, `dough-demo`). Every merchant call resolves the key to one
  restaurant and only touches offers/claims reachable from it. This is a prototype
  stand-in for real accounts.
- **Expiration.** Offers claimable only between start and end and when not paused.
- **Quantity.** `remaining = quantity - redeemed - live claims`. Quantity cannot be edited
  below units already held.
- **Claim expiration.** A claim holds one unit for **20 minutes** (`CLAIM_HOLD_MINUTES`) or
  until the offer ends, whichever is sooner. An unredeemed claim past that time becomes
  `expired`, its unit returns to availability, and its code can no longer be redeemed.
- **Duplicates.** One live or redeemed claim per student per offer; each code redeems once.
- **Matching** is deterministic (budget, time window, dietary tags). No external model call.
  The details screen explains each factor in plain language.

## Demo walkthrough

1. **Offers** tab: five demo offers (one paused offer is hidden). Tap "Under $5", "Right now"
   or "vegan" to filter.
2. Open "Harvest bowl for $8": read "Why this matches you", terms, eligibility and location.
   Diag Dough and Noodle Lab show dated entrance/construction notes.
3. Tap **Claim this offer**: a 6-character code appears and availability drops by one.
   Claiming again is refused.
4. **Redeem** tab: choose "Arbor Leaf", enter the code, tap **Redeem code**. Redeeming it
   again is refused; choosing "Noodle Lab" and entering the same code is refused.
5. **Manage** tab: edit the profile (entrance note + date), create a new offer, edit one,
   pause/resume. Paused offers disappear from discovery.

## Checks

```bash
jac clean --data --force && jac test services/promo.jac
```

Covers: persistence and idempotent seeding, merchant isolation (redeem + edit), expired and
not-started offers, exhausted quantity, abandoned-claim release, repeated redemption, paused
offers, filters and match explanations. For persistence across restarts: claim an offer,
restart the server, and confirm the code and availability are unchanged.

## Deferred

Payments, notifications, live routing, external data ingestion, garage-sale listings and
real authentication. New community sources plug in by producing records for
`import_restaurant`.
