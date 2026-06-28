# Phase 2M Final Preflight

Phase 2M stops at code-only validation. No deployment occurred, no live setting changed, no production service was contacted, and both kill switches remain false.

## Stage 0 Code-Only Checks

- Confirm `CALL_V2_ENABLED=false`.
- Confirm `CALL_V2_INTERNAL_TASKS_ENABLED=false`.
- Confirm V2 code builds and validates without Firebase initialization.
- Confirm the deployment validator returns sanitized output only.
- Confirm the preflight helper is blocked by default until explicit sanitized evidence is supplied.

## Infrastructure Preparation Placeholders

Use explicit operational values only when they are already approved. Do not invent production IDs, queue names, URLs, service accounts, or audience values.

- Firestore index readiness.
- TTL policy readiness.
- Cloud Tasks queue readiness.
- Cloud Tasks API and IAM readiness.
- OIDC target and audience readiness.
- Observability readiness.
- Operational owner assignment.
- Rollback owner assignment.
- Controlled rollout metadata only:
  - `rolloutMode` must be one of `internal_only`, `staff_only`, `percentage`, or `disabled`.
  - `rolloutPercentage` must be an integer from `0` to `100`.
  - `rolloutAllowlistCount` must be a non-negative integer in a bounded safe range.

## Internal-Task Canary Order

1. Keep both kill switches false.
2. Enable internal task processing only.
3. Verify dispatcher claim creation.
4. Verify authenticated timeout execution.
5. Verify stale replay safety.
6. Stop immediately on any anomaly.

## Staff-Only Client Canary Order

1. Complete the internal-task canary first.
2. Keep the internal switch enabled while draining backend work.
3. Require an explicit staff-claim administration acknowledgment if staff rollout is relevant.
4. Approve the rollout mode before any client enablement.
5. Do not proceed past this point without human approval.

## Evidence Required Before Enabling Each Switch

Before enabling `CALL_V2_INTERNAL_TASKS_ENABLED`:

- Deployment validator passed with explicit production configuration.
- Required Firestore index ready.
- Required TTL policies ready.
- Cloud Tasks queue, API, and IAM readiness recorded.
- Exact OIDC target and audience recorded.
- Observability configured.
- Operational owner assigned.
- Rollback owner assigned.

Before enabling `CALL_V2_ENABLED`:

- Internal-task canary passed.
- Three emulator runs passed.
- Rules tests passed.
- No unresolved private-data or logging finding remains.
- Rollout mode approval complete.
- Staff claim administration acknowledged when relevant.

## Rollback Order

1. Disable the client switch first.
2. Keep internal processing on and drain backend work.
3. Disable internal processing only after drain is complete.

## Stop Point

Stop here and request human approval before any deploy or live configuration change.

Phase 2M did not deploy anything.
