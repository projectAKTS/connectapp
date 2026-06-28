# Active Task — Phase 2M

Branch: `call-v2`
Accepted checkpoint: `060c3b2dd8f1a47e053d98d2ab1962598126cd3e`
Implementation commit message: `feat(call-v2): add final deployment preflight package`

## Goal

Create the final non-deployment preflight package for Helperly Call System V2. This phase must end at a human approval boundary. Do not deploy, enable kill switches, contact production services, connect Flutter, or change lifecycle/Cloud Tasks/outbox/legacy behavior.

## Allowed files

- `connect_functions/call_v2/**`
- `connect_functions/test/call_v2/**`
- `connect_functions/package.json`
- `connect_functions/package-lock.json`
- `docs/call-v2/**`

Do not modify `connect_functions/index.js`, Firestore rules/indexes, Firebase config, Flutter, native code, or `.github/**`.

## Deliverables

1. Add a pure, dependency-free preflight helper such as:

`connect_functions/call_v2/deployment_preflight_v2.js`

It must accept an explicit sanitized input object and return an immutable report containing only:
- overall status: `blocked` or `ready_for_human_approval`
- ordered stage names
- boolean checks
- controlled machine-readable blocker codes
- rollout mode, percentage, and allowlist count only when already sanitized

It must never accept or return raw secrets, salt, UIDs, emails, URLs, project IDs, service accounts, queue names, tokens, claims, payloads, call/task IDs, or credentials.

2. The report must cover these exact gates:
- both production kill switches still false for code-only validation
- deployment validator passed with explicit production configuration
- required Firestore index ready
- required TTL policies ready
- Cloud Tasks queue/API/IAM acknowledged
- exact OIDC target/audience acknowledged
- observability configured
- operational owner assigned
- rollback owner assigned
- rollout mode approval complete
- staff claim administration acknowledged when relevant
- three emulator runs passed
- rules tests passed
- no unresolved private-data/logging finding

3. Add a CLI-safe dry-run script or package command:

`npm run preflight:call-v2`

The default no-environment invocation must perform no network call, no Firebase initialization, no secret read, and produce a sanitized `blocked` report with controlled blocker codes. It must exit nonzero when blocked and zero only for an explicitly complete sanitized input.

4. Create:

`docs/call-v2/PHASE_2M_FINAL_PREFLIGHT.md`

Document:
- exact Stage 0 code-only checks
- infrastructure preparation placeholders without invented values
- internal-task canary order
- staff-only client canary order
- required evidence to record before enabling each switch
- rollback order: disable client switch first, drain with internal processing on, then disable internal processing
- explicit stop point requiring human approval before any deploy or live setting change
- no deployment occurred in Phase 2M

## Tests

Keep all existing tests passing and add focused tests proving:
- default preflight is blocked and sanitized
- each missing gate yields a controlled blocker code
- complete explicit sanitized input yields `ready_for_human_approval`
- no raw values can appear in report or CLI output
- unknown fields are rejected or ignored deterministically
- no network/Firebase initialization occurs
- report ordering is deterministic and immutable
- staff-only requirements apply only when relevant
- existing deployment validator behavior remains unchanged
- no production service is contacted

## Validation

Use Node 20:

```bash
cd connect_functions
node --version
npm install
npm run check:call-v2
npm run validate:call-v2:deployment
npm run preflight:call-v2 || true
npm run test:call-v2:rules
npm run test:call-v2:emulator
npm run test:call-v2:emulator
npm run test:call-v2:emulator
node --check index.js
cd ..
git diff --check
```

The default preflight command is expected to exit nonzero with a sanitized blocked report. Do not deploy.

## Handoff

Report exact files, preflight schema, blocker codes, CLI behavior, documentation, test totals, all three emulator results, Node version, and remaining risks. Confirm both kill switches remain false, no production values were invented, no production service was contacted, and nothing was deployed.

After Phase 2M passes review, stop automation and request human approval before any deployment or live configuration work.
