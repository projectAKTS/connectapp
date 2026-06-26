# Helperly Call V2 — Phase 1: Domain Model and Deterministic Reducer

## Purpose

Build the first isolated Call V2 implementation layer without changing any live call behavior.

This phase must introduce only pure Dart domain models, deterministic state reduction, and tests. It must not touch the legacy call flow, Firestore, Agora, PushKit, CallKit, FCM, routing, Cloud Functions, security rules, or deployment configuration.

## Safety boundary

- Work only on branch `call-v2`.
- `stable-jan4` remains the recoverable legacy baseline.
- Do not modify or delete legacy call files.
- Do not bind V2 to the application runtime.
- Do not deploy anything.
- Do not add feature flags yet.
- Do not add Firebase or Agora dependencies to the V2 domain layer.

## Architecture decisions already approved

### Durable lifecycle states

Use only:

- `ringing`
- `accepted`
- `active`
- `completed`
- `declined`
- `cancelled`
- `missed`
- `failed`

`expired` is not a normal public lifecycle state.

### Participant media states

Use:

- `notJoined`
- `preparing`
- `joining`
- `joined`
- `reconnecting`
- `disconnected`
- `left`
- `mediaFailed`

### Local UI/session phases

Use local-only phases such as:

- `idle`
- `presentingIncoming`
- `outgoingRinging`
- `openingCallRoute`
- `inCall`
- `closing`

These local phases must never be treated as durable backend lifecycle state.

### Core invariants

The reducer must preserve these invariants:

1. A terminal lifecycle never returns to a non-terminal lifecycle.
2. Duplicate events are harmless.
3. Stale versions are ignored.
4. A session is keyed by exactly one `callId`.
5. Events for another `callId` cannot mutate the active session.
6. `active` requires both required participant media states to be `joined` in the accepted lifecycle.
7. `remoteDetected` is diagnostic only and is not required for `active`.
8. Durable state, participant media state, local UI phase, and native presentation state remain separate.
9. The reducer performs no I/O.
10. The reducer emits explicit side-effect intents rather than executing side effects.

## Expected file structure

Codex may refine names if there is a clear reason, but keep the domain layer compact.

Suggested structure:

```text
lib/call_v2/domain/
  call_lifecycle.dart
  participant_media_state.dart
  call_local_phase.dart
  call_snapshot.dart
  call_event.dart
  call_effect.dart
  call_session_state.dart
  call_state_reducer.dart

test/call_v2/domain/
  call_state_reducer_test.dart
  call_state_invariants_test.dart
```

## Required domain concepts

### CallSnapshot

A backend/read-model snapshot containing only domain-safe fields needed by the reducer, for example:

- `callId`
- `version`
- `lifecycle`
- `callerUid`
- `calleeUid`
- caller participant media state
- callee participant media state
- relevant server timestamps
- terminal reason/failure code when present

Do not import Firestore types. Use plain Dart values.

### CallEvent

Model normalized inputs such as:

- authoritative snapshot received
- local user accepted
- local user declined
- local user cancelled
- local user ended
- local media preparing
- local media joining
- local media joined
- peer media joined
- media reconnecting
- media reconnected
- media failed
- native incoming presented
- native accepted
- native declined
- route opened
- route closed
- app resumed
- terminal snapshot received

Events must include enough identity/version data to reject stale or unrelated inputs.

### CallEffect

The reducer must return explicit effect intents, for example:

- request backend command
- present incoming route
- open call route
- close call route
- prepare Agora
- join Agora
- leave Agora
- end matching native CallKit call
- record diagnostic event
- clear scoped local session

Effects are data only. Do not call services from the reducer.

### CallSessionState

The local state should include at minimum:

- active `callId` or none
- latest authoritative version
- durable lifecycle
- local and peer participant media states
- local UI phase
- native presentation state if modeled here
- whether a route is open/opening
- terminal cleanup status
- dedupe identifiers required by the pure state machine

Keep the model immutable.

## Reducer requirements

Implement a pure function or pure reducer class that accepts:

```text
current state + event -> new state + effects
```

It must not:

- access Firebase
- access Agora
- access navigation
- access platform channels
- start timers
- mutate global state
- use arbitrary delays

## Minimum test matrix

Create deterministic tests covering at least:

1. Initial idle state receives a ringing snapshot.
2. Duplicate ringing snapshot produces no duplicate presentation effect.
3. Older snapshot version is ignored.
4. Snapshot for a different callId is rejected while another session is active.
5. Ringing -> accepted.
6. Accepted with only caller joined remains accepted.
7. Accepted with both caller and callee joined becomes active.
8. `remoteDetected` alone does not promote to active.
9. Active -> completed.
10. Ringing -> declined.
11. Ringing -> cancelled.
12. Ringing -> missed.
13. Accepted -> failed.
14. Terminal -> non-terminal transition is rejected.
15. Duplicate terminal event does not emit duplicate cleanup effects.
16. Route presentation is emitted at most once per callId.
17. Route closure is idempotent.
18. Media reconnecting/rejoined updates participant state without changing active lifecycle unnecessarily.
19. Event with stale version cannot reopen UI.
20. Cleanup effects are scoped to the matching callId.

Add invariant-focused tests for:

- terminal monotonicity
- version monotonicity
- callId isolation
- duplicate-event idempotency
- active promotion rule
- effect deduplication

## Quality requirements

- Prefer sealed classes or a similarly explicit event model where compatible with the project Dart version.
- Use exhaustive switches where practical.
- Avoid large inheritance hierarchies.
- Avoid premature serialization code.
- Avoid service locators and singletons in this phase.
- Add concise documentation only where behavior is non-obvious.
- Keep types immutable and testable.

## Required validation

Run at minimum:

```bash
flutter analyze
flutter test test/call_v2/domain
```

If project-wide `flutter analyze` fails because of unrelated pre-existing issues, report them separately and prove that the new files are clean.

Do not modify unrelated files to silence unrelated warnings.

## Commit boundary

This phase should end in one focused commit only after tests pass.

Suggested commit message:

```text
feat(call-v2): add deterministic call domain reducer
```

Do not merge to `stable-jan4` or `main`.

## External review handoff

The implementation response must be understandable to an external architecture reviewer who cannot see the Codex chat.

Report:

1. Active branch
2. Starting commit SHA
3. Ending commit SHA
4. Files inspected
5. Files created or changed
6. Domain decisions made
7. Any deviations from this task and why
8. Commands run
9. Full test results
10. Known failures or unverified behavior
11. Remaining risks
12. Exact recommended next phase

Separate confirmed facts from assumptions and hypotheses.
