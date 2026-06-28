# Active Task — Phase 2M Revision

Branch: `call-v2`
Accepted checkpoint: `060c3b2dd8f1a47e053d98d2ab1962598126cd3e`
Implementation baseline: `817b3c543866dada00f7b1c1ae6a60c89d50c4c0`
Implementation commit message: `fix(call-v2): harden preflight sanitized rollout inputs`

## Context

External review found one focused Phase 2M defect: `deployment_preflight_v2.js` accepts and returns arbitrary `rolloutMode` strings. This violates the Phase 2M requirement that reports never accept or return raw secrets, salts, UIDs, emails, URLs, project IDs, service accounts, queue names, tokens, claims, payloads, call/task IDs, or credentials. It also leaves `preflight_call_v2.js` able to echo an unsafe `CALL_V2_ROLLOUT_MODE` value in CLI output.

Do not deploy, enable kill switches, contact production services, connect Flutter, change lifecycle/Cloud Tasks/outbox behavior, or change legacy V1 behavior.

## Allowed files

- `connect_functions/call_v2/deployment_preflight_v2.js`
- `connect_functions/call_v2/preflight_call_v2.js`
- `connect_functions/test/call_v2/deployment_preflight_v2.test.js`
- `docs/call-v2/PHASE_2M_FINAL_PREFLIGHT.md`

Do not modify `connect_functions/index.js`, Firestore rules/indexes, Firebase config, Flutter, native code, `.github/**`, `AGENTS.md`, or `docs/agent-loop/**`.

## Required fix

1. Make rollout metadata strictly allowlisted and sanitized before it can appear in a report or CLI output.

Suggested safe rollout modes are controlled low-cardinality values only, for example:
- `internal_only`
- `staff_only`
- `percentage`
- `disabled`

Use names that fit the existing codebase, but do not allow arbitrary strings.

2. If `rolloutMode` is unknown, unsafe, oversized, URL-like, email-like, secret-like, or otherwise not a controlled value, do not echo it. Either omit it and add a controlled blocker code, or normalize it to a safe controlled value with a blocker. Keep behavior deterministic.

3. Bound numeric rollout metadata:
- `rolloutPercentage` must be an integer in an expected safe range, such as 0 through 100.
- `rolloutAllowlistCount` must be a non-negative integer within a reasonable bounded range.
- Invalid numeric values must not be echoed as-is and must not allow a ready report.

4. Keep the helper pure and dependency-free. No network calls, Firebase initialization, secret reads, production values, or environment reads inside `deployment_preflight_v2.js`.

5. Strengthen tests proving:
- arbitrary rollout mode strings are not returned
- URL/email/secret-like rollout mode values are not returned in helper reports or CLI output
- invalid rollout percentages/counts do not allow `ready_for_human_approval`
- valid controlled rollout modes and bounded numbers still allow readiness when all gates pass
- default blocked CLI output remains sanitized and nonzero
- complete explicit sanitized CLI input exits zero only when all gates and rollout metadata are valid

6. Update `PHASE_2M_FINAL_PREFLIGHT.md` if needed to document the controlled rollout metadata values and bounded numeric fields.

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

Report exact files, the rollout sanitizer/allowlist behavior, numeric bounds, blocker codes, CLI behavior, documentation changes, test totals, all three emulator results, Node version, and remaining risks. Confirm both kill switches remain false, no production values were invented, no production service was contacted, and nothing was deployed.
