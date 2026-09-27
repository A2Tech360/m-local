# Stable laptop hosting with updates from main

**Team URL: https://mlocal.tail0d5ef8.ts.net/**

The laptop runs the app, backend, and database. Tailscale Funnel provides public
HTTPS on the existing Free plan. Phones only need a browser, including on cellular
data. Keep the laptop awake, plugged in, and online. No paid hosting was created.

## Daily use

- `Start Stable Phone Demo.cmd`: start hosting and check main every 60 seconds.
- `Stop Stable Phone Demo.cmd`: stop this session and its owned backend.
- Push or merge changes into main, wait for checks and deployment, then refresh
  each phone. Local edits and commits on other branches do not deploy.

Keep the launcher window open. It prevents idle sleep without changing permanent
power settings. Public access can take about a minute to recover after restart;
the launcher waits for HTTPS readiness before displaying the link.

## How updates work

The latest push run of `.github/workflows/check.yml` must pass for the exact main
commit. The updater archives that revision into a temporary Linux directory,
installs dependencies, and runs Jac check and a production build while the old app
stays online. Existing compiler warnings do not fail Jac check.

After preflight succeeds, it stops the backend, switches the dedicated deployment
checkout, and starts the app in the same native runtime directory. The app briefly
becomes unavailable during restart. The gateway and public address stay in place;
accounts and stored data are retained.

Failed checks/builds keep the current version. Failed startup attempts to restore
and restart the previous source. Failed revisions are skipped until a new commit
or explicit redeploy. This restores source, not database/schema changes; coordinate
incompatible schema changes before merging.

Uncommitted changes in the deployment checkout suspend updates. Network operations
time out after 60 seconds and retry on the next poll. Preparation is limited to
nine minutes and removes its temporary workspace.

## Configuration and troubleshooting

Ignored `.jac/stable-link/config.json` selects `AppCheckout`, a separate clean
checkout reserved for deployment. Travis's setup reuses the existing phone-link
checkout and its database/SMTP settings. Hosting helpers stay in hosted-app.
Develop in the normal project checkout and push to main, not in the deployment
checkout.

Application frontend/backend and data/resource directories update automatically.
Gateway and launcher changes require a deliberate update/restart of the helper
checkout; they do not replace themselves while running.

Read `.jac/stable-link/deployment.json` for active commit, last check time, failed
revision and status. Candidate and app logs are in the same ignored directory.
Review logs before sharing them; never share private account/configuration files.

From **PowerShell** in the helper checkout:

```powershell
.\scripts\stable-demo.ps1                 # normal start and main updates
.\scripts\stable-demo.ps1 -RedeployCurrent # retry/rebuild the current main
.\scripts\stable-demo.ps1 -NoAutoUpdate    # keep current app version
```

Stop an existing hosting launcher before changing startup options.

## Persistent state

Never remove or relocate these during code updates:

- The app checkout's private `.jac/onboarding.env` and demo-account files.
- `~/.local/share/m-local/phone-demos/<checkout-key>/`, including its private
  `.jac` data, account/role configuration, and recorded running revision.
- Jac's PostgreSQL store under `~/.cache/m-local/pg/`.
- `~/.local/state/m-local/tailscale/`, containing identity, certificates and
  Funnel configuration. Replacing or renaming the device can change the URL.

Tailscale 1.102.4 was installed without administrator rights inside WSL from its
official checksum-verified archive. A new machine needs setup-stable-link.sh, the
running app and stable-link service, then stable-link login and publish. Sign-in
and Funnel enablement must be completed for that account.

## Verification

Public browser offers and distinct student/merchant sessions were verified.
Private admin/schema/raw signup routes returned 403. Deployment tests use real
disposable Git repositories to verify CI rejection, dirty-checkout protection,
bounded subprocesses and source rollback. Source-sync tests preserve private data.

On September 27, a real preflight/build/backend replacement completed at main
`ffa9878`. Three login tokens issued before deployment still authenticated as the
same student/merchant identities afterward; existing offer IDs were unchanged.
The 20 gateway/UI tests, deployment safety tests, and two source-sync tests passed.
The UI tests use the runtime-installed React/QR libraries under WSL; a bare Windows
test run without those built dependencies cannot run the QR roundtrip test.

New email delivery and physical phone-camera scanning remain acceptance checks.
Funnel is a free beta service with bandwidth limits and depends on the laptop's
connection.

References: [Tailscale Funnel](https://tailscale.com/docs/features/tailscale-funnel),
[same URL across restarts](https://tailscale.com/docs/use-cases/application-testing/share-local-dev-server-with-internet).
