# Active Task - Cloud Functions Runtime Node.js 22

Branch: `call-v2` (known-good tags `stable-calls-oct-26` -> `46a71e9` and
`stable-calls-oct-27` -> `1e2d550`; do not modify them or
`stable/calls-oct-26`)

Starting SHA: `1e2d5503a2531e09abd2bcd1b6dc215330cb6ead`

Authorized by the user on 2026-10-27, after TestFlight 202610261913 passed
on two devices (3 audio + 1 video + 1 cellular call).

## Problem

Google decommissions the Node.js 20 runtime for Cloud Functions on
2026-10-30. After that date no function on `nodejs20` can be deployed or
updated. All 18 deployed functions (17 gen2 + `onAuthUserCreated` gen1)
run `nodejs20`, as declared in `firebase.json` and
`connect_functions/package.json`.

A runtime change takes effect only when the functions are redeployed from
local source. Two risks follow:
- `index.js` also exports 11 Call V2 functions that are not deployed. An
  unscoped `firebase deploy --only functions` would create them.
- The deployed functions come from at least six separate deploys, and
  `connect_functions/` has changed many times since May 2026. A redeploy
  ships the current local code of every function.

## Goal

Move the runtime to Node.js 22 with no behavior change, and prepare an exact,
scoped redeploy of only the 18 currently deployed functions. Compare the
deployed source with the local source before the user deploys.

## Allowed Files

- `firebase.json` (functions `runtime` only)
- `connect_functions/package.json` (`engines` only)
- `connect_functions/package-lock.json` (root `engines` only)
- `docs/agent-loop/NEXT_TASK.md`, `docs/agent-loop/STATE.json`,
  `docs/agent-loop/HANDOFF.md`

## Required Implementation

1. `firebase.json`: set `runtime` to `nodejs22`.
2. `package.json` and lockfile: set `engines.node` to `22`. Dependency
   versions stay unchanged, including the `firebase-functions` 5.1.1 major
   version.
3. Under Node 22, every exported module loads and the server unit tests pass.
4. Run a deploy dry run scoped to the 18 deployed function names.
5. Compare deployed with local source per function: download the deployed
   archives read-only, or get equivalent evidence. Report every behavioral
   difference before the deploy command is handed to the user.

## Strict Non-Goals

- No new functions, Call V2 enablement, dependency upgrades, rule changes or
  app changes.
- No TestFlight build.
- Claude does not deploy. The user runs the scoped deploy command after
  reviewing the source comparison.

## Validation

- `node --test` for `test/call_invites` and `test/call_v2`, run under Node
  22. The emulator-only file is excluded.
- `require('./index.js')` under Node 22, with the export list checked.
- Scoped deploy dry run.
- Lockfile diff limited to `engines`.
- `git diff --check`.

## Commit And Handoff

- Commit the implementation as `chore(functions): move runtime to Node.js 22`.
- Commit the handoff as
  `chore(agent-loop): record node22 runtime review handoff`.
- Push `call-v2` only.
