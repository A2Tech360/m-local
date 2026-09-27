# Separate sessions with a shared catalog

Travis confirmed that each tester should have an independent login and private
editing state while everyone sees the same published offers. Keep one backend
and persistent database. Each distinct account owns its profile, preferences,
company and claims; each browser profile holds its own authentication token.

## Implementation and acceptance

1. Raise only the trusted-network email-code burst allowance enough for four
   teammates on the same Wi-Fi. Preserve per-email cooldowns, attempt limits and
   the global email budget. Prove both group access and continued rate limiting.
2. Exercise four verified accounts through the real sharing gateway against a
   disposable backend. Use concurrent requests to check actor isolation, private
   profiles, distinct company ownership, shared publication, forbidden
   cross-owner writes and last-unit claim safety. Send no real email.
3. Keep four Chromium contexts open together. Verify separate editing state,
   shared offers, isolated account changes and logout. Restart the disposable
   backend and verify durable account/ownership/publication data.
4. Document the shared-host testing procedure and the distinction between
   separate devices/browser profiles and tabs sharing the same browser storage.
5. Run relevant checks, commit and push to main, verify exact-commit CI, then
   deliberately update the hosting helper so its gateway receives the fix.

Use the existing clean task worktree. Preserve the primary checkout's concurrent
analytics/authentication work. Do not create acceptance fixtures on the public
host or replace its account database.

## Evidence

Source inspection found account-keyed storage and request-bound Jac identities,
but the ingress allowed only three code sends per minute per public IP. A real
gateway regression reproduced statuses 200/200/200/429 for four simultaneous
testers. With the change all four pass, and the thirteenth request is rejected.
The allowance is twelve/minute and thirty/hour; verification and backend email
limits are unchanged. Tests also exposed and fixed Retry-After choosing an
hourly wait shorter than the remaining minute wait.

All seventeen tooling JavaScript tests and forty-six onboarding/security tests
passed. Independent read-only review found no material issue and separately ran
the limiter boundary tests.

The disposable HTTP run used four real verified actors through gateway 8241.
Concurrent account edits, company activation, preferences and publication stayed
isolated. Guest and all four authenticated feeds shared the published offers.
Cross-owner edits and QR reads/redemptions were denied; simultaneous last-unit
claims and duplicate redemption each produced exactly one winner.

Four Chromium contexts at 390px passed shared publication, independent unsaved
drafts, private merchant management, isolated profile edit/reload, and logout
isolation without page errors or horizontal overflow. Both backend and gateway
were then restarted with the same store: all four identities, preferences,
business ownership, posts, consumed stock and redemption state persisted.

These are automated browser contexts, not four physical devices. No real email
was sent and no test records were created on the public host.
