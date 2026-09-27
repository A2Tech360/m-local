# Feed reliability after sample removal

Travis asked whether missing offers meant important work was overwritten and
requested a robust backend. The live app is running b8b15fd. Both feed APIs
returned HTTP 200 with the same real offer; a fresh 390px browser displayed it.
The demo cleanup changed no backend service files. Local concurrent work remains
in the primary checkout and is outside this change.

## Bounded fixes

1. Reject missing or malformed home-feed responses so backend failure cannot
   appear as a valid empty catalog. Keep sample records hidden.
2. Provide an explicit refresh action on successful and empty feeds. Refresh the
   visible feed every 30 seconds and when focus/connectivity returns; avoid
   overlapping automatic requests and remove inactive listeners/timers.
3. Preserve a student's active saved claim in the personalized feed when its
   merchant pauses the offer or the student changes discovery filters. Other
   visitors must not see paused offers or someone else's private claim.
4. Require both runtime readiness and a valid anonymous home-feed response for
   public health checks. Return only the readiness boolean, under one deadline.

## Verification

- Reproduce missing-response and stale-feed failures with the compiled client.
- Reproduce paused/filtered saved-claim loss with isolated Jac tests.
- Add HTTP acceptance for real business publication appearing in home_feed,
  saved-QR retention, and isolation from other visitors.
- Run pinned Jac checks, core/security tests, build, compiled browser tests,
  gateway checks, and disposable real account/post HTTP and Chromium flows.
- Commit/push only these scoped changes, verify exact-SHA CI and deployed feed.

No sample records or user accounts will be deleted or reclassified. No test
records will be created on the public host.

## Verified locally

Pinned Jac check/build, 193 core tests, 46 onboarding/security tests, 63 compiled
browser tests, and 11 targeted gateway tests passed. The HTTP saved-claim case
failed before the backend fix and passed afterward. Account/profile/post state
survived a real disposable-server restart. Chromium passed the business/profile/
publication flows at 390px and simulated disconnect/online recovery at 320px.

Live read-only diagnosis: ten direct backend requests and ten public feed
requests all succeeded. No independent connection loss was reproduced. The
existing laptop deployment flow deliberately interrupts service during restart;
automatic client recovery does not make that hosting arrangement zero-downtime.
