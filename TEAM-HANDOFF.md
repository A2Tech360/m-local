# M-Local / PromoPusher team handoff

For the four-person build, use [the team mission and starting prompts](docs/START-HERE.md).
That plan follows the source audit and defines work still to be implemented. The
extraction manifest and verification report below describe the original capture;
later documentation and engineering changes are tracked separately in Git history.

## What this repository contains

The application source recovered from Travis's JacHammer project **M-Local** on
September 26, 2026. The generated interface and README still use **PromoPusher**.
This is the team's prototype for time-limited Ann Arbor restaurant offers.

Source project: https://jachammer.ai/project/prj_91a1ccd4ab324e15b8dac8ef0f6e03d7

All 11 application, configuration and documentation files visible in the expanded
project explorer were copied through the browser editor. Every file was copied
twice; both copies and the saved UTF-8 text matched. The original snapshot is commit
`715b4badee054af755beec1b5ab7d3274cd7d6c5`. Clipboard copies used CRLF line endings;
this is an editor-content recovery, not a raw sandbox filesystem export.

`EXTRACTION-MANIFEST.json` records file sizes and SHA-256 hashes. Application code
has not been rewritten during extraction. The follow-up commit adds this handoff,
the manifest, verification evidence and ignore rules for credentials and local files.
The manifest's original `.gitignore` hash refers to the first commit.

The sandbox `.env`, assistant journal/build plan, generated caches and runtime
database were not exported. Demo data is available in `services/seed.jac`.

## Start here

1. Clone `https://github.com/CosmonautJones/m-local.git`.
2. Read `README.md` for setup, the demo walkthrough and architecture.
3. Agree on a shared Jac runtime before upgrading or editing generated code.

The generated README reports Jac **0.34.20**, Python **3.12.14**, Node **22.23.3**
and npm **10.9.9**. JacHammer's Settings page showed **Default**, not an explicit
version pin. Travis's separate WSL lab currently has Jac **0.37.21**. Compatibility
between those versions has not been established by this export.

With the agreed runtime and dependencies available, the generated setup commands
are below. Run them from the cloned project directory in **WSL Bash**:

```bash
jac install
jac start --dev main.jac
```

Open the address printed by the server. These are the source README's instructions;
they were not executed as part of this extraction. No hosted-model credential was
exported. Matching is implemented with ordinary rules, without a model call.

## Verification status

- PASS: 11 source files copied twice and matched against local contents (83,434 bytes).
- PASS: referenced local Jac modules are present.
- PASS: bounded credential-pattern scan found no keys. Demo merchant keys are intentional.
- NOT RUN: local installation, compilation, browser flows or runtime test suite.
- Seven test cases are present in `services/promo.test.jac`. Their presence is not a pass result.

`EXPORT-VERIFICATION.json` records the checks actually run. The source README's
runtime and coverage claims came from the generator and still need team verification.

## First team work

1. Reproduce startup and run `jac test services/promo.jac` in a disposable local
   checkout. The generated tests manipulate demo graph state; do not use them on
   a shared running demo database. The README's reset command deletes local data.
2. Check student discovery, claim, merchant management and redemption end to end.
   JacHammer's activity reported missing redemption feedback; reproduce that before fixing it.
3. Replace the fixed demo merchant keys and client-supplied student identity before
   accepting real users. Audit ownership, concurrent claims and one-time redemption.
4. Pin compatible dependencies and record startup/test results on a fresh clone.
5. Retain event-time commit history, document generated/template provenance, complete
   the required Baz review and confirm submission requirements with the organizers.

The UI, graph schema and backend rules are in `.jac` source files. A formal
hackathon language-percentage calculation or eligibility review has not been done.

Use feature branches and pull requests so teammates can work without overwriting
one another. No license has been selected; public visibility alone is not an
open-source license grant.
