# Email and business onboarding

Travis requested U-M email code verification instead of university SSO, then
business creation from a website. Resend SMTP is now configured on the local
phone host, and Travis confirmed verification works for two real U-M accounts.

## Intended flow

- People enter a uniqname beside a fixed, muted `@umich.edu` suffix. The server
  builds and validates the address. A six-digit, expiring, single-use code proves
  inbox access, then creates or resumes an application account. This does not
  certify enrollment and never asks for a university password.
- Business owners use their work email and the same code flow. They paste a
  public website URL or enter details manually. A bounded importer collects
  public text, structured restaurant data, image candidates and menu links.
  Optional Jac `by llm()` extraction organizes those facts into an editable draft.
  No website content becomes executable instructions or grants ownership.
- The owner reviews every field and selected image/menu link, then saves a
  private business application for review. Existing restaurant access remains
  controlled by the trusted merchant mapping. Importing a site cannot claim it.
- Existing provisioned demo/merchant login remains available. Missing email/AI
  configuration produces an honest setup state; no public code echo or fake
  verification. AI is optional; manual entry and structured website import work
  without a model.

## Implementation and verification

1. Inspect Jac's real authentication extension points and reuse runtime sessions.
2. Write tests for address validation, expiry/replay/attempt/send limits, delivery
   failure, and concurrent verification before implementing email verification.
3. Add website fetching with public-address-only DNS resolution, bounded sizes,
   redirect validation, limited same-site pages, and no browser/script execution.
   Test unsafe URLs, structured extraction, prompt injection boundaries and errors.
4. Add typed Jac endpoints and private business drafts; connect responsive forms
   with review, retry, resend and cancel states. Preserve guest and demo flows.
5. Run backend/security tests, Jac checks/build, compiled UI checks and isolated
   HTTP smoke tests. Real email receipt and real model extraction require operator
   configuration and are not claimed from fixture tests.
6. Document exact sender/model setup and public ingress allowlist. Keep the running
   phone demo available until the replacement is built and checked.

## First-visit experience (approved direction, September 26)

On the first visit, show **Find local deals** and **List my business** before the
feed or any login form. Persist the selected path in the browser and open its
email form. Later visits and sign-out keep that same path, without the other
path's signup toggle or legacy-login copy. A restored authenticated account's
server role overrides an old browser preference; this preference grants no
permissions. Verified students do not see business creation, and business viewers
do not receive student claim-login prompts.

Verify with compiled UI tests for each first-visit selection, return visits,
sign-out, restored sessions, and absence of the other path's controls. Then check
Jac, build the app, review the phone layout, and include the result in the pending
main-branch release.
