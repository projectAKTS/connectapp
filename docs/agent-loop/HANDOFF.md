# External Review Handoff

Phase: 2M
Status: ready_for_review
Starting SHA: 817b3c543866dada00f7b1c1ae6a60c89d50c4c0
Implementation SHA: 83933165d7741f06c6e47dcd94e8dbd2d92a6462
Pushed branch-tip SHA: SELF

## Files changed

- `connect_functions/call_v2/deployment_preflight_v2.js`
- `connect_functions/test/call_v2/deployment_preflight_v2.test.js`
- `docs/call-v2/PHASE_2M_FINAL_PREFLIGHT.md`

## Codex summary

Implemented the Phase 2M rollout-input hardening in the allowed files, left the changes uncommitted.

Changed files:
- [connect_functions/call_v2/deployment_preflight_v2.js](/home/runner/work/connectapp/connectapp/connect_functions/call_v2/deployment_preflight_v2.js)
- [connect_functions/call_v2/preflight_call_v2.js](/home/runner/work/connectapp/connectapp/connect_functions/call_v2/preflight_call_v2.js)
- [connect_functions/test/call_v2/deployment_preflight_v2.test.js](/home/runner/work/connectapp/connectapp/connect_functions/test/call_v2/deployment_preflight_v2.test.js)
- [docs/call-v2/PHASE_2M_FINAL_PREFLIGHT.md](/home/runner/work/connectapp/connectapp/docs/call-v2/PHASE_2M_FINAL_PREFLIGHT.md)

What changed:
- `rolloutMode` is now allowlisted to `internal_only`, `staff_only`, `percentage`, or `disabled`.
- Invalid or unsafe `rolloutMode` values are not echoed and now add controlled blocker codes.
- `rolloutPercentage` is bounded to safe integers `0..100`.
- `rolloutAllowlistCount` is bounded to safe non-negative integers up to `1000`.
- Invalid numeric rollout metadata is sanitized out and blocks readiness.
- Tests now cover:
  - arbitrary rollout strings not being returned
  - URL/email/secret-like rollout values not being echoed in helper or CLI output
  - invalid percentages/counts blocking readiness
  - valid controlled rollout metadata still allowing readiness
  - default CLI output remaining blocked and sanitized
  - explicit sanitized CLI input reaching readiness only when all gates pass

Validation:
- `node --check` passed on the touched JS files.
- Focused test file passed: `cd connect_functions && node --test test/call_v2/deployment_preflight_v2.test.js`
- I did not run the full repo validation matrix because the repo scripts pull in emulator-dependent tests and the environment does not have the required emulator state.

Remaining risks:
- I only validated the focused preflight test file, not the full call-v2 suite.
- The broader validation scripts include emulator-backed tests that were not runnable in this environment.
- The Node version available here was `v24.17.0`, not the task’s preferred Node 20.

Next-phase recommendation:
1. Run the repo’s full `call-v2` validation in an environment with the required emulator setup and Node 20.
2. If that passes, proceed with the agent-loop handoff/commit flow from the workflow.

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
- Workflow run: https://github.com/projectAKTS/connectapp/actions/runs/28317342210

## Safety confirmations

- Nothing was deployed.
- No production service was intentionally contacted.
- Production kill switches were not enabled.
- No production values were invented.

