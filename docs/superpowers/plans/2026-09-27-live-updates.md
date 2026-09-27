# Live updates from main

Keep the existing Tailscale URL and phone-demo database. While the Windows hosting
launcher runs, poll GitHub main every 60 seconds. Only deploy the exact commit
whose latest push run of `check.yml` completed successfully.

1. Test remote revision selection, dirty-checkout protection, failed/pending CI
   rejection, and rollback using disposable Git repositories.
2. Preflight each new revision in an isolated native Linux directory with Jac
   check and build while the current app continues serving.
3. Switch the dedicated phone-link checkout, restart its backend using the same
   native runtime directory, and verify offers. Restore the previous code if
   startup fails. Keep private data and configuration untouched.
4. Integrate the updater into Start/Stop Stable Phone Demo. Record the active
   revision and deployment result locally. Retry network errors; do not repeatedly
   deploy a revision that failed preflight or startup.
5. Exercise a real restart and public login, then document the refresh workflow.

No automatic merges, force resets, database resets, schema rollback guarantees,
paid services, or edits to another human's application files. Uncommitted changes
in the dedicated deployment checkout suspend updates until resolved.
