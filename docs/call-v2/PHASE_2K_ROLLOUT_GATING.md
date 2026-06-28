# Helperly Call System V2 Phase 2K Rollout Gating

Phase 2K adds server-side client eligibility on top of the existing global V2 kill switch. No deployment was performed in this phase, no production rollout values were added, and both kill switches remained false.

## Control Layers

`CALL_V2_ENABLED` is the global emergency client switch. When it is false, no V2 client callable may execute, including commands for existing calls.

`CALL_V2_INTERNAL_TASKS_ENABLED` is independent. Timeout execution, outbox dispatch, and scheduled outbox recovery are controlled only by the internal switch and do not depend on client rollout eligibility. This lets existing backend work drain even when client entry is stopped.

The rollout policy is evaluated only after authentication and only when `CALL_V2_ENABLED` is true.

## Rollout Modes

Supported modes:

- `off`: no client is eligible
- `staff`: only users with trusted custom claim `callV2Staff === true`
- `allowlist`: only exact UIDs in the server-side allowlist
- `percentage`: deterministic UID allocation
- `all`: every authenticated user is eligible

The default rollout mode is `off`. The global switch still overrides every mode.

## Trusted Staff Signal

Staff eligibility uses only the trusted Firebase Auth custom claim:

```text
request.auth.token.callV2Staff === true
```

String values such as `"true"`, public profile fields, request data, and client-provided role/cohort fields are not trusted. Assigning and removing the custom claim is an operational admin action outside Phase 2K.

For callee eligibility in staff mode, production wiring uses a trusted Admin Auth lookup and checks `customClaims.callV2Staff === true`. Auth lookup failures fail closed.

## Allowlist

The allowlist is a server-controlled comma-separated parameter.

Rules:

- entries are trimmed
- exact duplicates are removed
- empty internal entries are malformed
- maximum unique UID count is 500
- UIDs must match the accepted bounded UID format
- no wildcards, prefixes, regex, emails, or domains are supported
- parsed UIDs are never returned to clients

Missing or invalid allowlist configuration fails closed.

## Percentage Allocation

Percentage rollout uses SHA-256 over a canonical input containing:

- fixed namespace/version
- UID
- rollout salt

The result maps into bucket `0..9999`. A user is selected when:

```text
bucket < percentage * 100
```

The same UID and salt are stable. Increasing percentage does not reshuffle existing buckets. Changing the salt intentionally reshuffles allocation, so salt rotation should be treated as a deliberate rollout reset.

The bucket and salt are never exposed to callable clients.

## Start-Call Eligibility

`startCallV2` requires:

- authenticated caller
- `CALL_V2_ENABLED=true`
- caller eligible under the current rollout policy
- callee eligible under the same rollout policy

Callee eligibility is resolved server-side. The client cannot supply cohort, percentage, staff, role, allowlist, or bucket data.

If either participant is ineligible, the callable returns a generic `failed-precondition` with `callV2Code: "call_v2_not_enabled_for_user"`. It does not reveal rollout mode, allowlist membership, staff claim status, percentage, salt, bucket, or internal reason.

## Existing Calls

Existing-call commands are not re-gated by cohort changes:

- `acceptCallV2`
- `declineCallV2`
- `cancelCallV2`
- `endCallV2`
- `reportParticipantMediaV2`
- `renewActiveCallLeaseV2`

They still require authentication and `CALL_V2_ENABLED=true`. Domain participant checks remain authoritative.

This avoids stranding active calls when rollout mode or allowlist membership changes after a call has started.

## Rollout Order

1. Keep `CALL_V2_ENABLED=false`.
2. Keep `CALL_V2_INTERNAL_TASKS_ENABLED=false` until backend infrastructure is ready.
3. Enable internal task processing only after Cloud Tasks and OIDC configuration are verified.
4. Configure rollout mode and required server-only values.
5. For staff canary, assign trusted custom claims and verify operational ownership.
6. Enable `CALL_V2_ENABLED=true` only after internal processing is healthy.
7. Move from `staff` to `allowlist`, `percentage`, or `all` only after measurable gates are healthy.

`all` mode requires explicit deployment acknowledgement so it cannot be selected accidentally.

## Emergency Rollback

If client behavior is unsafe, disable `CALL_V2_ENABLED` first. This stops new starts and existing-call client commands as an emergency stop.

Keep `CALL_V2_INTERNAL_TASKS_ENABLED=true` long enough to terminalize and drain existing backend work. Disable internal processing only after drain.

If only cohort behavior is unsafe while the global switch remains true, change rollout mode to `off`, `staff`, or a smaller allowlist/percentage. Existing calls may continue through participant-authorized commands while new starts are blocked by the revised policy.

## Validation Notes

Phase 2K added server-only rollout configuration and tests. It did not deploy, did not enable either kill switch, did not connect Flutter, did not add production values, and did not contact production Firebase Auth, Cloud Tasks, APNS, FCM, or Agora.
