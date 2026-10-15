# Active Task - Durable Accepted-Call Boundary Diagnostics

Branch: `call-v2`

Starting SHA: `f2654d9bbd28adc95471add25bf86d819f623991`

## Goal

Add bounded, durable, privacy-safe diagnostics for the two unresolved physical
acceptance boundaries without changing call behavior:

- Audio B reached `accept_transaction_start`, but no authoritative transaction
  outcome was retained.
- Video C reached native CallKit presentation and the user reported tapping
  Accept, but retained evidence could not prove native answer-callback execution
  or Flutter bridge receipt.

Do not assume these failures share a root cause.

## Authorized Scope

### Durable Local Recorder

- Add the smallest device-local recorder that survives Flutter process
  termination and restart.
- Persist UTC time, monotonic event order where available, safe stage, app
  lifecycle state, and privacy-safe fingerprints for invite and exact CallKit
  identity.
- Retain enough bounded history for at least three consecutive calls.
- Bound storage by event count, encoded size, and age.
- Keep storage inspectable through the existing device-container extraction
  workflow.
- Recorder failures must be swallowed and must never alter call handling.
- No diagnostic write may be awaited before CallKit fulfillment, Firestore
  transaction execution, media startup, or native ownership acknowledgment.

### Native Accept Boundary

Instrument the existing native path with independently durable checkpoints for:

- fresh CallKit presentation;
- `CXAnswerCallAction` callback entry;
- accepted identity storage;
- native safety-watch start;
- Flutter MethodChannel dispatch attempt and completion/result when available;
- CallKit answer fulfillment;
- CallKit audio activation/deactivation;
- native route-owned and media-owned acknowledgment;
- safety-watch deadline;
- exact native-call termination.

Native callback execution, bridge dispatch, and Flutter receipt must remain
separate facts. Never infer receipt from dispatch.

### Flutter Accept Boundary

- Persist receipt immediately when `callkitAcceptedNative` enters
  `NotificationService._handleNativePushMethodCall`.
- Persist safe identity-match classification and accepted-recovery handoff.
- A lightweight native diagnostic receipt acknowledgment is allowed only if it
  is non-blocking and cannot affect acceptance behavior.

### Authoritative Accept Transaction

Instrument `_acceptInviteTransactionWithRetry()` without changing authority,
retry, timeout, or status-transition behavior. Capture:

- accepted continuation claimed and current lifecycle generation;
- attempt start and `runTransaction` invocation;
- transaction callback entry and snapshot acquisition;
- safe authoritative-status classification;
- transaction completion;
- timeout/Firebase failure using a normalized safe category;
- retry entry;
- typed accepted/already-accepted/rejected/unavailable result.

The existing eight-second timeout must remain unchanged. App lifecycle changes
around this operation may be persisted where existing platform callbacks expose
them.

### Post-Accept Media Boundary

Add only safe stages for:

- exact audio readiness known/waiting;
- physical media ownership claimed/rejected;
- process cleanup gate requested/permitted/blocked;
- token request start;
- media runtime start;
- Agora join callback;
- media-owned acknowledgment completion;
- media cleanup start/completion;
- lifecycle return to idle.

## Allowed Files

Modify or add only files strictly required from:

- `lib/call_v2/diagnostics/**`
- `lib/services/notification_service.dart`
- `lib/services/call_session_manager.dart`
- `lib/call_v2/real_flow/**` only for diagnostic checkpoints
- `lib/screens/call/agora_call_screen.dart` only for diagnostic checkpoints
- `ios/Runner/AppDelegate.swift`
- focused tests under `test/call_v2/**`
- `test/notification_foreground_recovery_test.dart` only if required
- `ios/RunnerTests/RunnerTests.swift`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/STATE.json`
- this task file

## Privacy And Retention

Persist no raw APNs/Agora token, personal name, phone number, user ID,
authorization credential, invite ID, channel, payload, exact CallKit UUID, or
Agora credential. Correlation fingerprints must be stable enough for local
ordering but non-reversible and must not expose source values.

Do not write diagnostics to `callInvites`, Cloud Functions, or any backend.
Make no dependency changes.

## Strict Non-Goals

Do not change:

- native CallKit Accept or incoming presentation behavior;
- accepted transaction implementation, authority, retry, or timeout;
- exact CallKit ownership;
- PushKit/APNs delivery;
- physical media owner or Agora runtime behavior;
- video or outgoing-audio route-first sequencing;
- native safety-watch duration;
- route-owned or media-owned acknowledgment semantics;
- redial ordering or terminal transitions;
- backend, Firestore protocol/rules, dependencies, Flutter, Agora, or plugin
  versions.

Do not deploy, build TestFlight, request another physical call, or claim a root
cause or physical fix.

## Required Tests

1. Native Accept checkpoints persist in order.
2. Native dispatch and Flutter receipt are represented independently.
3. Missing Flutter receipt is never fabricated.
4. A blocked Firestore transaction retains its last entered checkpoint.
5. A completed transaction retains its typed result.
6. Timeout/exception stores only a safe normalized category.
7. Process restart preserves bounded diagnostic history.
8. Call A/B/C histories remain independently correlated.
9. Old-call cleanup cannot overwrite newer-call identity.
10. Storage failures do not affect CallKit acceptance, Firestore, or media.
11. Persisted diagnostics contain no sensitive raw values.
12. Diagnostic persistence does not delay native answer fulfillment.

## Validation

Run focused diagnostics, accepted-recovery, route-ownership, exact-CallKit,
background-media, rapid-lifecycle, and repeated-call tests, then:

```bash
flutter analyze
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

Run iOS RunnerTests because native diagnostics are authorized. Inspect dependency
diffs and confirm no dependency metadata changed.

## Commit And Handoff

Create one focused instrumentation commit. Then replace `HANDOFF.md`, set
`STATE.json` to `ready_for_review` with exact validation evidence, commit the
metadata separately, push `origin/call-v2`, and stop.

Do not build TestFlight or request physical validation in this task.
