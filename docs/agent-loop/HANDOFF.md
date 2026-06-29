# External Review Handoff

Phase: 3A accepted; Phase 3B prepared
Status: task_ready
Accepted Phase 3A implementation: `009a1f372fabe26fe10394519ff47739788d982a`
Accepted Phase 3A workflow: `28369246060`
Accepted Phase 3A job: `84042624356`

## Phase 3A review result

Phase 3A is accepted after exact review.

Confirmed accepted properties:

- `CallV2RequestContext` contains only `callId` and `version`; it no longer accepts `actorUid` or participant role authority.
- Callable request payloads serialize only safe client data such as `callId`, `version`, and media-report fields.
- `domain/call_v2_models.dart` is harmless exports only and no longer duplicates enums/models/parser logic.
- Accepted local phase names remain `idle`, `presentingIncoming`, `outgoingRinging`, `openingCallRoute`, `inCall`, and `closing`.
- `CallSessionManagerV2` uses injected local participant role only for local phase derivation, not as authenticated request authority.
- Caller ringing maps to `outgoingRinging`; callee ringing maps to `presentingIncoming`; accepted maps to `openingCallRoute`; active maps to `inCall`; terminal maps to `closing` until cleanup.
- Equal/lower snapshots are rejected for the same owned call.
- Terminal ownership cannot be replaced by lower/equal nonterminal data.
- A different call is ignored while nonterminal ownership exists.
- Terminal cleanup clears ownership, clears queued command state, and returns local phase to `idle` idempotently.
- Duplicate in-flight command taps with the same command key produce exactly one transport request.
- Failed commands do not mutate durable snapshot state.
- `CallNavigationCoordinatorV2` is stateful and dedupes open and close intents without touching `Navigator` or existing routes.
- Client errors expose controlled error codes instead of raw provider/server messages.

## Validation evidence

Workflow run `28369246060` completed successfully. Job `84042624356` shows successful backend and Flutter validation, skipped failure-log steps, successful implementation commit, successful handoff write, and successful push.

Retained handoff validation summary:

- Node 20 backend checks passed.
- Deployment readiness validation passed.
- Firestore rules tests passed.
- Full backend emulator suite passed three times.
- Flutter formatting passed.
- Focused Flutter analysis passed.
- Focused Flutter tests passed.
- `git diff --check` passed.

## Phase 3B handoff

`NEXT_TASK.md` now contains the authoritative Phase 3B task: build a disabled-by-default, fake-testable Flutter Call V2 client harness/facade around the accepted Phase 3A primitives.

Phase 3B must remain non-production and must not wire startup, existing routes, native call stacks, push, Firestore listeners, Agora, CallKit, PushKit, FCM, production Firebase, live services, IAM, OIDC, queues, secrets, kill switches, or rollout configuration.

## Safety

V1 files were not modified. The V2 feature gate remains disabled by default. No deployment occurred. No production service was contacted. No live configuration was changed. No production values were invented.
