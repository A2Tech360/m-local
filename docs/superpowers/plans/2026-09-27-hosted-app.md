# Permanent team hosting

Goal: one stable HTTPS URL for independent phone testing, serving the existing
Jac frontend and backend with accounts, claims, and onboarding surviving restarts.

Scope update: Travis requires free laptop hosting. Use an existing-domain named
Cloudflare tunnel if available, otherwise Tailscale Funnel. Paid deployment is
deferred. The production process, storage, and gateway validation remain useful.

Implemented architecture: unprivileged WSL Tailscale Funnel routes HTTPS to a
restricted loopback Node gateway, then Jac 0.37.23. The native demo runtime path
stays fixed across updates, preserving graph/account/onboarding state. No product
logic was changed. Optional paid-host preparation was removed after the free-only
decision; no paid service was provisioned.

1. Extend the existing gateway with opt-in readiness and explicit edge trust;
   test real HTTP forwarding, compressed JSON, rate limits, and blocked routes.
2. Verify the pinned runtime and build; add supervised startup without changing
   the existing persistent store. Disable default admin bootstrap in app config.
3. Exercise offers, sessions, blocked endpoints, shutdown, and persistent restart
   locally; measure memory. Record any limits honestly.
4. Add stable Tailscale setup, Windows start/stop controls, and hosting instructions.
5. Verify public HTTPS, offers, separate sessions, and restart with the same URL.
   Physical phone scanning and new email delivery remain user acceptance checks.

Constraints: preserve other engineers' files, do not copy live demo databases,
keep credentials out of Git/images/logs, no paid resources without budget approval.
SMTP is required for real sign-in; the existing private configuration is retained.
