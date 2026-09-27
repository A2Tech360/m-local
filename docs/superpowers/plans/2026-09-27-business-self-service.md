# Business self-service testing

Travis requested removal of business approval on September 27 so the team can
test signup and publishing themselves. No app-specific approval page exists.
This overrides the earlier pending-review policy for this increment.

## Behavior

Saving a complete profile from a verified business account registers its own
restaurant immediately. Existing pending profiles activate on explicit save.
The app refreshes the server session and opens offer management. Email proof,
representation confirmation, field validation and per-business ownership remain.

The server generates a stable restaurant slug, persists ownership privately,
and creates/updates the public restaurant and location under the existing
mutation lock. A browser cannot choose its owner or attach to another restaurant.
Repeated saves and runtime retries must preserve one listing and its existing
offers. Existing provisioned demo merchants continue working.

## Work

- [x] Backend: private ownership registry and idempotent profile activation.
- [x] UI: remove approval copy, open management after save, recover session
  refresh failure without submitting the profile twice.
- [x] Tests: legacy pending profile activation, cold save/retry, second account
  isolation, self-service publish/claim/redeem, restart persistence, and existing
  merchant regressions.
- [x] Validate compiler/build and compiled/real browser flows, update current
  docs, review, and commit only this scope to main.

Keep concurrent simulation/design work untouched. Use the existing disposable
`onboarding-check` workspace for tests; never reset the shared phone-demo store.
