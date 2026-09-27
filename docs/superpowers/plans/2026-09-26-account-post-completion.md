# Account and offer completion plan

**Goal:** Finish the existing student and company signup/login, profile editing,
and restaurant offer posting flows, verify them together, and commit to main.

**Architecture:** Keep Jac 0.37.23 authentication and server-derived ownership.
Use the private onboarding store for account names and pending company profiles;
keep public restaurant profiles and offers in the existing graph. UI consumes
protected RPCs. A verified business application remains pending until approved.

**Scope:** Travis authorized implementation, agent delegation, testing, and a
main-branch commit on September 26. Existing unrelated local files and the open
access-context PR are outside this work. No deployment or real mail is required.

## Work and interfaces

- [x] Inspect current source, runtime, team contract, Git state and open PRs.
- [x] Account backend agent: add `get_account_profile()` and
  `save_account_profile(display_name: str)` in `services/account_profile.jac`.
  Both return `ok`, `message`, `display_name`, `email`, `role`, `email_verified`,
  `is_demo`. Persist only editable display names; derive identity from the
  request. Test account isolation, invalid names, immutable roles and emails,
  session refresh, and business-only draft access.
- [x] Offer backend agent: finish validation and truthful success/failure in
  existing `save_offer`, `update_profile`, and status operations. Test rejected
  updates leave prior state intact, ownership denial, new post visibility,
  and preservation of held claim terms.
- [x] UI agent: explicit login/signup modes, account editing, existing company
  draft editing, approved merchant profile editing, create/edit offer forms.
  Test validation, loading, failure retention, save/reopen, audience switching,
  publishing/list refresh and session-safe responses in the compiled UI.
- [x] Coordinator: allowlist the two new profile RPCs at phone ingress. Extend
  isolated real HTTP checks for account and company persistence and ownership;
  verify merchant create/edit/publish and public discovery.
- [x] Run Python, Jac, UI/tooling, compiled-browser and real HTTP tests in a
  disposable store; build the production artifact; independently review diff.
- [x] Record results and limitations, stage only this work, and commit to main.

## Review focus

Rejected form submissions must not mutate stored data or show success. Pending
companies must never gain merchant authority by editing profile fields. Logout
must discard late private responses. New offers must not duplicate on retries
caused by a failed list refresh. Existing saved claims must retain their terms.
Student account edits must persist across sign-in and server restart.

## Validation boundaries

Tests use local fictional accounts and intercepted test email challenges. They
do not send mail, certify a phone camera, approve a company, or deploy the app.
The existing running phone demo is preserved. Browser fixtures verify client
behavior; actual HTTP tests separately verify runtime identity and persistence.

## Integration findings

Independent review found and regression-tested tab-navigation draft loss,
pending profile-save overwrites, and an encoding regression. All are corrected.
Real HTTP testing then reproduced duplicate posts on the first publish after
startup. Jac's read-tier retry was interrupted by unconditional transaction
commit in cleanup; failed attempts now unwind without committing, and failed
lock acquisition closes the descriptor. See `docs/ACCOUNT-POST-VALIDATION.md`.

The supplied whiteboard wireframe establishes a useful later business navigation
direction: company profile, its posts, then a post composer. Logo/post photos,
a dedicated company-page layout and persistent customer preferences were not
added to this completion pass.
