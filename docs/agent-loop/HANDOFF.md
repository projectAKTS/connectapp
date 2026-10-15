# Durable Accepted-Call Boundary Diagnostics Handoff

STATUS: `ready_for_review`

STARTING_SHA: `f2654d9bbd28adc95471add25bf86d819f623991`
AUTHORIZATION_SHA: `425a250df16405fef0910a80382b03d82f0481c9`
IMPLEMENTATION_SHA: `b017ab007308fe31837174f2e06269f5dd7202c5`
ENDING_SHA: `SELF`

## Scope

This change adds bounded, device-local diagnostics for the two unresolved
accepted-call boundaries. It does not diagnose a root cause and does not change
CallKit acceptance, Firestore acceptance, route ownership, media ownership,
Agora behavior, retry policy, timeout policy, terminal transitions, or backend
behavior.

## Durable Storage

- Native checkpoints are stored in iOS `UserDefaults` under
  `connectapp.callV2DurableAcceptedBoundaryEvents`, with a separate monotonic
  sequence key.
- Dart checkpoints are stored under Application Support at
  `call_v2_diagnostics/flutter_accepted_boundaries.json`.
- Both stores retain at most 384 events, 128 KiB, and 14 days of history.
- Both stores use the same SHA-256 namespace scheme and persist only 16-character
  call and exact-CallKit fingerprints, never raw ownership values.
- Native writes run asynchronously on a utility queue. Dart writes use a
  serialized fire-and-forget queue. Recorder failures are isolated from call
  handling.

The stores survive app/process restart and remain available through device
container extraction. Tests prove independent A/B/C histories, restart
persistence, bounded retention, and that old-call cleanup appends cannot
overwrite newer-call identity.

## Native Accept Checkpoints

`AppDelegate.swift` now durably records:

- fresh CallKit presentation;
- native answer callback execution;
- accepted exact identity storage;
- native safety-watch start/deadline;
- Flutter bridge dispatch and its normalized completion result;
- CallKit answer fulfillment;
- exact audio-session activation/deactivation;
- route-owned and media-owned acknowledgments;
- exact native-call end request, end, and verification.

Dispatch is not treated as Dart receipt. Native diagnostics never fabricate
`FLUTTER_ACCEPT_BRIDGE_RECEIVED`; that checkpoint exists only in Dart.

## Flutter Receipt And Recovery

`NotificationService._handleNativePushMethodCall` records
`flutterAcceptBridgeReceived` immediately after parsing
`callkitAcceptedNative`. Accepted identity classification and the manager
handoff are separate durable events. Lifecycle callbacks also record the exact
safe lifecycle state associated with the current accepted owner when present.

## Transaction Boundary

`CallSessionManager._acceptInviteTransactionWithRetry()` now records, without
changing its existing eight-second timeout or three-attempt policy:

- accepted continuation claim and lifecycle-generation check;
- transaction attempt and `runTransaction` invocation;
- transaction callback entry and Firestore snapshot completion;
- authoritative status classification;
- typed transaction completion/result;
- normalized timeout/Firebase/recoverability failure category;
- retry entry.

The deterministic blocked-transaction test proves callback entry remains
persisted while `tx.get` has not completed, and then proves snapshot, status,
completion, and typed result checkpoints after release. The test-only callback
hook is conditionally awaited only when configured, so production execution has
no added suspension before `tx.get`.

## Media Boundary

Narrow checkpoints cover exact audio-session readiness, physical media owner
claim/rejection, cleanup-gate request/result, token-request start, media-runtime
start, Agora join callback, exact media-owned acknowledgment, media cleanup,
and lifecycle return to idle.

## Privacy

Persisted records contain UTC timestamp, monotonic sequence, safe stage,
lifecycle state, fixed-length fingerprints, safe enum outcome, and optional
attempt/generation booleans or counters. They contain no raw invite ID, CallKit
UUID, user ID, channel, token, payload, credential, name, phone number, or
authorization value.

## Files Changed

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`
- `lib/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart`
- `lib/call_v2/real_flow/call_v2_agora_media_runtime.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/diagnostics/call_v2_durable_boundary_diagnostics_test.dart`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

The pre-existing untracked
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` remains untouched. Its SHA-256 after
validation is
`d33b3bf300a4980807b863d6c4b29465548284b1c6004638dcfa7fbcb2eda0f3`.

## Validation

- New durable diagnostics: 10 passed.
- Focused physical ledger and ownership/lifecycle group: 205 passed.
- Foreground recovery: 3 passed.
- Full isolated Call V2 suite: 2,356 passed.
- iOS RunnerTests: 30 passed, 0 failed.
- `flutter analyze`: passed with no issues.
- `git diff --check`: passed.
- Dependency diff: none for `pubspec.yaml`, `pubspec.lock`, `ios/Podfile`, or
  `ios/Podfile.lock`.

Historical path-isolation tests reject unrelated untracked files. For the full
suite only, the pre-existing architecture document was moved outside the
repository and restored with identical SHA-256 immediately afterward.

## Safety

No timeout, retry, CallKit ownership, watchdog, Firestore protocol, transaction
authorization, route, terminal, media-owner, Agora, PushKit/APNs, backend,
dependency, or rollout behavior changed. No backend/Firebase deployment or
TestFlight build was performed. No production service was contacted.

ROOT_CAUSE_CLAIM: `NONE`

## Next

Review the durable boundary instrumentation and automated evidence. Do not
request a TestFlight build or physical call until review explicitly authorizes
it.
