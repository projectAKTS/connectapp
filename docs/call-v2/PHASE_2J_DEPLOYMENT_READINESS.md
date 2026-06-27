# Helperly Call System V2 Phase 2J Deployment Readiness

This phase prepares backend code and configuration for a later controlled deployment. No deployment was performed in Phase 2J, no kill switch was enabled, and no production resource values are defined here.

## Firestore Access Boundaries

V2 public call documents live at `calls/{callId}` and participant documents live at `calls/{callId}/participants/{participantUid}`.

Authenticated clients may read a V2 call only when their UID is one of the exact authoritative participants in `participantUids`. Authenticated participants may read both participant documents for the same V2 call. Clients may not create, update, or delete V2 call or participant documents.

These private operational paths deny all client reads and writes:

- `callOps/{callId}`
- `callOps/{callId}/{document=**}`
- `activeCallLocks/{uid}`
- `callCommandKeys/{key}`

Private data includes commands, task outbox entries, lock claims, fencing tokens, idempotency records, dispatch state, execution state, and diagnostics. Participation in a call never grants access to private operational documents.

V1 compatibility is preserved by using explicit V2 detection via `callSystem == "v2"` and leaving existing legacy collections such as `callInvites` under their prior rules.

## TTL Policies

Configured TTL field overrides:

- `callCommandKeys.ttlAt`
- `commands.ttlAt` for `callOps/{callId}/commands/{commandId}`
- `taskOutbox.ttlAt` for `callOps/{callId}/taskOutbox/{taskId}`
- `calls.historyExpiresAt`
- `callOps.opsRetentionExpiresAt`

Firestore TTL deletion is asynchronous and must never be used as call lifecycle authority. Timeout processors and domain services remain authoritative for lifecycle transitions.

`historyExpiresAt` is set only for terminal public call history. Nonterminal calls must not receive `historyExpiresAt`.

Firestore field overrides are collection-group scoped. The `commands` TTL applies to every `commands` collection group. No narrower path-scoped TTL exists in Firestore index configuration, so the safe configuration relies on V2 command records using the accepted `commands` collection group and avoids inventing unsupported nested syntax.

## Index Audit

Most V2 operations use direct document references:

- Calls: `calls/{callId}`
- Participants: `calls/{callId}/participants/{uid}`
- Operations root: `callOps/{callId}`
- Commands: `callOps/{callId}/commands/{commandId}`
- Task outbox: `callOps/{callId}/taskOutbox/{taskId}`
- Locks: `activeCallLocks/{uid}`
- Idempotency: `callCommandKeys/{key}`

The only new V2 query introduced in Phase 2J is stranded-outbox recovery:

- Collection group: `taskOutbox`
- Filter: `status == "pending"` or `status == "dispatching"`
- Order: `updatedAt ASC`
- Limit: bounded

This requires one collection-group composite index on `taskOutbox(status ASC, updatedAt ASC)`. No broad public query over private V2 collections is introduced.

## Stranded-Outbox Recovery

`recoverPendingTaskOutboxV2` performs bounded backend-only recovery over the `taskOutbox` collection group.

Recovery queries only:

- `pending`
- `dispatching`

It does not recover:

- `dispatched`
- `dead_letter`
- acknowledged/completed dispatched tasks

Each candidate task is passed to the accepted dispatcher. The dispatcher remains authoritative for non-expired claims, expired claim recovery, deterministic external task identity, provider `already_exists`, max attempts, TTL expiry, and malformed task rejection.

Recovery returns aggregate counts only:

- `examined`
- `dispatched`
- `alreadyDispatched`
- `deadLetter`
- `busy`
- `retryable`
- `stale`
- `failed`

It does not return payloads, UIDs, call IDs, task IDs, fencing tokens, or error messages. One malformed or failed task increments `failed` and does not abort the batch.

## Scheduled Recovery

`recoverCallV2TaskOutbox` is scheduled every 5 minutes and guarded by `CALL_V2_INTERNAL_TASKS_ENABLED`.

When disabled, scheduled recovery returns:

```json
{
  "status": "disabled",
  "examined": 0
}
```

It performs no query, no outbox mutation, and no Cloud Tasks call while disabled. This avoids an intentional disabled-state retry storm. The document-created trigger still fails closed while disabled so newly created outbox events can retry after configuration is enabled.

When enabled, scheduled recovery uses the same publisher factory, strong claim tokens, bounded processing, and accepted dispatcher as the document-created trigger. It does not call timeout processors, mutate lifecycle state directly, send notifications, sleep, poll, or recursively invoke itself.

## Deployment Readiness Validator

`validateCallV2DeploymentConfig` validates deployment readiness without network calls.

Rules:

- Both switches false is valid for code-only deployment.
- `CALL_V2_ENABLED=true` while `CALL_V2_INTERNAL_TASKS_ENABLED=false` is invalid.
- Internal tasks enabled requires explicit region, project ID, location, queue ID, target URL, service account email, and audience.
- Target URL and audience must be absolute HTTPS URLs.
- Service account email must be a valid service-account address.
- No value is invented.
- Returned readiness output is sanitized and does not include raw URLs, service account emails, credentials, or project values.

CLI dry run:

```bash
cd connect_functions
npm run validate:call-v2:deployment
```

The CLI reads explicit environment variables only as a deployment utility. It performs no Firebase initialization and no network calls.

## Stage 0 — Code-Only Deployment

- `CALL_V2_ENABLED=false`
- `CALL_V2_INTERNAL_TASKS_ENABLED=false`
- Verify legacy functions remain present.
- Verify V2 exports exist but reject client calls through the kill switch.
- Verify no V2 Firestore activity from clients.
- Verify no Cloud Tasks API call occurs during import or disabled invocation.

## Stage 1 — Infrastructure Preparation

- Create the Cloud Tasks queue explicitly.
- Create or choose the OIDC service account explicitly.
- Grant only required queue-enqueue permissions to the function runtime identity.
- Grant only required endpoint-invocation permission to the OIDC service account.
- Configure the target URL explicitly.
- Configure the exact OIDC audience explicitly.
- Configure TTL policies.
- Configure the `taskOutbox(status, updatedAt)` collection-group index.
- Keep both kill switches false.

Use placeholders in operational commands:

```bash
# gcloud tasks queues create <QUEUE_ID> --location <LOCATION> --project <PROJECT_ID>
# gcloud run services add-iam-policy-binding <SERVICE> --member serviceAccount:<SERVICE_ACCOUNT_EMAIL> --role <INVOKER_ROLE>
```

Do not substitute fabricated project IDs, regions, emails, queue names, or URLs.

## Stage 2 — Internal Task Canary

- Keep `CALL_V2_ENABLED=false`.
- Enable `CALL_V2_INTERNAL_TASKS_ENABLED=true`.
- Seed a controlled backend-only V2 test call/task.
- Verify outbox creation.
- Verify dispatcher claim.
- Verify deterministic external task identity.
- Verify authenticated endpoint execution.
- Verify execution acknowledgement.
- Verify stale replay safety.
- Disable the internal switch immediately on anomaly.

## Stage 3 — Staff-Only Client Canary

- Proceed only after the internal pipeline is healthy.
- Because the current switch is global, add a server-side cohort/staff gate before this stage or keep `CALL_V2_ENABLED=false`.
- Do not claim a staff cohort mechanism exists until it is implemented and tested.

## Stage 4 — Percentage Rollout

Future work. A server-side cohort or percentage gate must exist before percentage rollout. The current global kill switch alone is not enough for percentage rollout.

## Stage 5 — General Availability

Measurable gates:

- Timeout success rate
- Outbox pending age
- Dispatch failure and dead-letter count
- Endpoint unauthorized count
- Duplicate/stale task rate
- Call terminalization correctness
- Lock recovery rate
- Legacy/V2 cross-processing absence

## Rollback

1. Disable `CALL_V2_ENABLED` first.
2. Keep internal tasks enabled long enough to drain existing V2 calls and outbox work.
3. Disable `CALL_V2_INTERNAL_TASKS_ENABLED` only after drain.
4. Never disable internal processing first while allowing new V2 calls.
5. Keep legacy available.
6. Do not delete V2 data during emergency rollback.

## Required IAM and Operational Checklist

- Cloud Tasks API enabled.
- Queue exists.
- Runtime enqueue identity has only required enqueue permission.
- Endpoint invoker permission is granted only to the OIDC service account.
- OIDC service account identity is explicit.
- Audience exactly matches configured endpoint strategy.
- TTL policies are configured.
- Required index is ready.
- Logs redact payloads, UIDs, fencing tokens, provider diagnostics, and credentials.
- Alerts exist for pending age and dead letters.
- Kill-switch owner is assigned.
- Rollback owner is assigned.
- No deploy was performed during Phase 2J.
