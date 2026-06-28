# External Review Handoff

Phase: 2L
Status: ready_for_review
Starting SHA: 2c900daa013dad50ad2ae0fbcf18944dea329c11
Implementation SHA: 060c3b2dd8f1a47e053d98d2ab1962598126cd3e
Pushed branch-tip SHA: SELF

## Files changed

- `.agent-codex-final.md`
- `connect_functions/call_v2/deployment_readiness_v2.js`
- `connect_functions/call_v2/firebase_wiring_v2.js`
- `connect_functions/call_v2/observability_v2.js`
- `connect_functions/call_v2/validate_deployment_v2.js`
- `connect_functions/index.js`
- `connect_functions/test/call_v2/deployment_readiness_v2.test.js`
- `connect_functions/test/call_v2/firebase_wiring_v2.test.js`
- `connect_functions/test/call_v2/observability_v2.test.js`
- `docs/call-v2/PHASE_2L_CANARY_OBSERVABILITY.md`

## Codex summary

Implemented Phase 2L as uncommitted workspace changes only. No commits, pushes, state/handoff edits, deployment, production contact, or rollout enablement.

Changed files:
- `connect_functions/index.js`
- `connect_functions/call_v2/firebase_wiring_v2.js`
- `connect_functions/call_v2/observability_v2.js`
- `connect_functions/call_v2/deployment_readiness_v2.js`
- `connect_functions/call_v2/validate_deployment_v2.js`
- `connect_functions/test/call_v2/firebase_wiring_v2.test.js`
- `connect_functions/test/call_v2/observability_v2.test.js`
- `connect_functions/test/call_v2/deployment_readiness_v2.test.js`
- `docs/call-v2/PHASE_2L_CANARY_OBSERVABILITY.md`

Summary:
- Moved `CALL_V2_ROLLOUT_SALT` to `defineSecret` and bound it only to the seven V2 callable exports.
- Added disabled-by-default `CALL_V2_OBSERVABILITY_ENABLED`.
- Added privacy-safe, allowlisted operational observability with injected sink and lazy disabled path.
- Instrumented callable, rollout, outbox, scheduled recovery, and timeout HTTP boundaries only.
- Extended deployment readiness with sanitized canary acknowledgement checks.
- Documented canary observability, enablement order, dashboards/alerts placeholders, and rollback order.

Validation run with Node `v20.20.2`:
- `npm run check:call-v2` passed.
- `node --test test/call_v2/observability_v2.test.js test/call_v2/firebase_wiring_v2.test.js test/call_v2/deployment_readiness_v2.test.js` passed.
- `npm run validate:call-v2:deployment` passed.
- `node --check index.js` passed.
- `git diff --check` passed.

Remaining risk:
- I did not run the emulator validation suite. A broad `npm run test:call-v2` fails in this environment because emulator-dependent tests require `FIRESTORE_EMULATOR_HOST`; the workflow should run the full required emulator suite afterward.

Suggested next phase: Phase 2M should be review-driven, focused on validating the secret binding metadata, observability schema safety, and canary readiness behavior before any deployment planning.

## Validation

- Node 20 workflow environment
- `npm ci`: passed
- `npm run check:call-v2`: passed
- `npm run validate:call-v2:deployment`: passed
- Firestore rules tests: passed
- Full emulator run 1: passed
- Full emulator run 2: passed
- Full emulator run 3: passed
- `node --check index.js`: passed
- `git diff --check`: passed
- Workflow run: https://github.com/projectAKTS/connectapp/actions/runs/28310772171

## Safety confirmations

- Nothing was deployed.
- No production service was intentionally contacted.
- Production kill switches were not enabled.
- No production values were invented.

