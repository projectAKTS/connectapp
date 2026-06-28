# Phase 2L Canary Observability

Phase 2L prepares Call System V2 for a controlled backend canary. No deployment was performed, no production service was contacted, no production value was invented, and both kill switches remain default false:

- `CALL_V2_ENABLED=false`
- `CALL_V2_INTERNAL_TASKS_ENABLED=false`

## Protected Rollout Salt

`CALL_V2_ROLLOUT_SALT` is declared as a protected Firebase secret parameter for production function wiring. The secret is bound only to the seven V2 callable exports:

- `startCallV2`
- `acceptCallV2`
- `declineCallV2`
- `cancelCallV2`
- `endCallV2`
- `reportParticipantMediaV2`
- `renewActiveCallLeaseV2`

The internal task outbox trigger, timeout HTTP endpoint, and scheduled recovery export do not receive the rollout salt secret and do not depend on client rollout eligibility. The secret is resolved lazily during invocation when rollout policy evaluation needs it. There is no secret read during module import.

The deployment validator may still read an explicit `CALL_V2_ROLLOUT_SALT` environment value for offline validation only. Validator output is sanitized and never prints the salt.

## Safe Event Schema

Operational observability is dependency-injected at the Firebase wiring boundary and is disabled unless `CALL_V2_OBSERVABILITY_ENABLED=true`. Domain lifecycle reducers do not depend on console logging or global logging state.

Supported event names are versioned:

- `call_v2.client_callable_outcome.v1`
- `call_v2.start_rollout_decision.v1`
- `call_v2.outbox_dispatch_outcome.v1`
- `call_v2.scheduled_recovery_outcome.v1`
- `call_v2.timeout_http_outcome.v1`

Allowed fields are bounded, low-cardinality operational values only:

- `schemaVersion`
- `eventName`
- `outcome`
- `callableName`
- `rolloutMode`
- `httpStatusClass`
- aggregate scheduled recovery counters
- `retryable`
- `verificationResult`

Never record raw UIDs, call IDs, task IDs, command IDs, channel names, chat IDs, payloads, request bodies, allowlist entries, rollout salt, rollout bucket, custom claims, bearer tokens, OIDC claims, service-account email, target URL, audience, fencing tokens, lock claims, provider messages, stack traces, or credentials.

Unknown event names, unknown outcomes, unknown fields, oversized strings, negative counters, and non-plain field values are rejected or dropped before reaching the sink. Sink failures are best-effort and must not change lifecycle behavior, HTTP responses, callable responses, or retry semantics.

## Instrumentation Boundaries

Instrumentation is limited to Firebase wiring boundaries:

- Client callables record one callable outcome category.
- `startCallV2` rollout eligibility records only `eligible` or `denied`, plus rollout mode.
- Rollout denial is generic and does not expose exact reason, staff status, allowlist membership, or bucket.
- Task outbox created trigger records normalized dispatcher outcome and retry category only.
- Scheduled recovery records aggregate counters only.
- Timeout HTTP wrapper records verification result, status class, and retry category only.

Internal task processing remains independent from client rollout eligibility.

## Canary Enablement Order

1. Deploy code with both kill switches false.
2. Confirm `CALL_V2_ROLLOUT_SALT` exists as a protected secret for callable exports.
3. Configure `CALL_V2_OBSERVABILITY_ENABLED=true` only after safe dashboards and alert placeholders are ready.
4. Keep `CALL_V2_ENABLED=false`.
5. Enable `CALL_V2_INTERNAL_TASKS_ENABLED=true` to allow internal processing to drain safely.
6. Validate timeout endpoint authorization and task dispatch/recovery behavior.
7. Configure a non-`off` rollout mode with required acknowledgements.
8. Enable `CALL_V2_ENABLED=true` only for the approved canary mode.

## Required Dashboard And Alert Placeholders

Create dashboards and alerts for these metrics before client canary:

- Callable failures by callable name and outcome.
- Start-call rollout denials by rollout mode.
- Pending task age.
- Dispatch retry and dead-letter counts.
- Timeout retry categories.
- Unauthorized timeout endpoint requests.
- Lock recovery counts.
- Terminalization correctness.

Do not encode project IDs, URLs, owner names, emails, salts, allowlists, or service accounts in documentation.

## Canary Readiness Validator

When client rollout is enabled, the validator requires explicit acknowledgements that:

- Safe observability is configured.
- An operational owner is assigned.
- A rollback owner is assigned.
- Staff custom claims are managed when staff rollout is used.

Internal-only mode remains valid without client-canary acknowledgements. Both switches false remains valid for code-only deployment.

Sanitized output may expose booleans, rollout mode, rollout percentage, and allowlist count. It must not expose names, emails, identifiers, URLs, salts, allowlists, or secrets.

## Rollback Order

1. Disable `CALL_V2_ENABLED` first to stop new client V2 starts.
2. Keep `CALL_V2_INTERNAL_TASKS_ENABLED=true` while accepted internal processing drains.
3. Watch pending age, dispatch retries, timeout retries, lock recovery, and terminalization correctness.
4. Disable `CALL_V2_INTERNAL_TASKS_ENABLED` only after the queue is drained or an explicit incident decision requires stopping internal processing.

Phase 2L made no deployment and left both kill switches false.
