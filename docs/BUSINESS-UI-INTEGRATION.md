# Business UI integration for main

Scope: integrate PR #11 with the approved private business Insights increment,
replace the business feed entry with Insights, and repair profile field overlap.
Unrelated local onboarding, simulation, branding, and place work stays outside
this integration.

Plan:
- [x] Compare current main, PR #11, and local Insights dependencies.
- [x] Integrate in a separate worktree to preserve concurrent local edits.
- [x] Make Insights the first merchant tab and sign-in/restoration destination.
- [x] Keep unconfigured businesses in setup and students in their own feed.
- [x] Remove zero-basis flex allocation from stacked profile fields.
- [x] Verify compiler, isolated rules/analytics, compiled UI, and phone geometry.
- [ ] Merge through a PR, then verify checks on the resulting main commit.

Business navigation is Insights, Manage, Redeem, Account. Competitor browsing is
not part of this release. Metrics describe recorded claims and redemptions, not
page views or payment revenue. New profiles transition to Insights after setup.

`python tests/ui/mobile-business-layout.py` checks actual Chromium geometry at
320, 390, and 430 CSS pixels using the compiled app and synthetic RPC responses.
It is layout/navigation evidence, not live account or physical Safari evidence.
The Insights HTTP acceptance suite remains available for isolated test stores.

Local verification on 2026-09-27: Jac 0.37.23 check and sealed production build
passed; 194 core tests, 46 Jac analytics tests, 9 Python analytics tests,
6 Node analytics tests, 69 compiled UI tests, and 26 UI/tooling unit tests passed.
Onboarding, offline recap Chromium, and PowerShell deployment safety checks passed.
Chromium phone geometry passed at all three widths with no browser errors.
Physical iPhone Safari remains a team testing step after deployment.
