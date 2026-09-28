# Review Handoff

STATUS: `ready_for_review`

STARTING_SHA: `e184070eea659f59e24482690230d31931c0e6bf`
IMPLEMENTATION_SHA: `d04d2d6b5d6eb5e2357930a532b6cc7611fea3d7`
ENDING_SHA: `SELF`

## Root Defects Corrected

- The accepted native CallKit UUID stopped at `_CallSession`; `AgoraCallScreen`
  reconstructed an identifier from invite/channel instead of owning the exact
  native UUID.
- Normal screen teardown ended the reconstructed call, called process-wide
  `endAllCalls()`, then enumerated and ended every remaining native call.
- `flutter_callkit_incoming` 3.0.0 can redirect plugin end behavior through its
  process-global PushKit state, so passing A to plugin cleanup did not prove A
  remained the actual target after B arrived.
- Accepted incoming setup called plugin `setCallConnected()`, which can produce
  another native answer action for a call already accepted through CallKit.
- Hard reset and stale-native cleanup did not consistently re-check exact
  ownership after asynchronous work and could classify pending/accepted B as
  stale while A was finishing.
- Stored accepted recovery clearing was process-wide rather than exact-ID
  scoped.

## Exact UUID Propagation

Before:

`AppDelegate -> NotificationService -> CallSessionManager -> _CallSession`

`AgoraCallScreen` then derived a CallKit identity from invite/channel.

After:

`AppDelegate -> NotificationService -> CallSessionManager -> _CallSession ->
AgoraCallScreen`

The screen uses `acceptedCallkitId` when present. Legacy/outgoing flows with no
exact accepted UUID retain the existing normalized fallback.

## Normal CallKit Cleanup

Before, normal screen cleanup used plugin `endCall()`, process-wide
`endAllCalls()`, and active-call enumeration. After, a screen ends only its
owned identity. Exact accepted iOS calls use the Helperly method-channel
`endExactCallkitCall`; legacy/non-iOS fallback continues using the plugin's
single-call operation. Process-wide cleanup remains available only at the
explicit signed-out/app-reset boundary.

## Plugin Global-State Protection

`CallV2ExactCallkitEndRequester` parses the supplied exact UUID and submits a
`CXEndCallAction` through Helperly's own `CXCallController`. It never reads the
plugin's process-global `isFromPushKit` or `self.data`. Requests for one exact
UUID are coalesced and successful repeated cleanup is idempotent, without
touching another UUID.

## SetCallConnected Change

An already accepted incoming call with an exact native UUID skips plugin
`setCallConnected()`. Legacy/outgoing calls keep their marker, now only after
the Agora join callback rather than during pre-RTC setup. This prevents a
synthetic second native Accept for the already accepted PushKit call.

## Hard Reset And Stale Sweep

- Screen hard reset supplies its expected invite and exact CallKit identity;
  stale A reset requests are ignored after B owns the manager.
- Cleanup re-checks session/generation ownership after awaited subscription,
  native-end, and stale-sweep boundaries.
- Pending prompt, pending accepted, route continuation, native route watch,
  current session, and accepted native identities are protected from stale
  cleanup.
- Unknown native calls are ended only after a server read proves their invite
  missing or terminal; read failure preserves the call.
- Signed-out app reset retains an explicit all-native cleanup boundary.
- Stored accepted recovery clearing is scoped to the matching exact UUID.

## Async Ownership Guarantees

Late A cleanup cannot clear B session state, B accepted recovery, or B native
ownership. Route ACK remains after successful route opening only and carries
the exact accepted UUID. The accepted Firestore authority, route architecture,
and watchdog duration are unchanged.

## Regression Tests

- `accepted screen ownership chooses exact UUID over normalized fallback`:
  exact native identity wins over reconstructed fallback.
- `legacy screen ownership preserves normalized fallback`: legacy behavior is
  preserved when no exact accepted UUID exists.
- `accepted incoming setup skips synthetic plugin connected action`: accepted
  incoming setup cannot synthesize a second Accept.
- `legacy connected marker remains available after RTC join`: outgoing/legacy
  behavior remains after media join.
- `normal cleanup uses exact native end and never plugin global state`: A ends
  exactly even while simulated plugin-global ownership points to B.
- `A B C screen cleanup remains exact and sequential`: three calls clean only
  their respective native identities.
- `normal Agora screen cleanup has no process-wide end operation`: screen
  source contains no `endAllCalls()` or active-call sweep.
- `exact accepted UUID reaches route recorder and route ACK`: exact identity
  reaches the routed screen boundary and native ACK unchanged.
- `delayed A hard reset protects accepted B and cleans terminal orphan C`: B is
  preserved during delayed A cleanup while a provably terminal orphan remains
  cleanable.
- `stale A cleanup request cannot reset newer B session`: post-await stale A
  completion cannot mutate B.
- `testExactCallkitEndTargetsOnlySuppliedUuidDespiteNewerGlobalState`: native
  exact A end is immune to newer simulated plugin-global B and is idempotent.

Existing notification ownership and rapid lifecycle suites continue to prove
duplicate accepted delivery produces one route/RTC owner, pending ownership is
generation-scoped, terminal cleanup is exact, and route ACK occurs only after a
successful push.

## Validation Counts

- `flutter analyze`: passed, no issues.
- Exact CallKit ownership: passed, 10 tests.
- NotificationService accepted ownership: passed, 38 tests.
- CallSessionManager rapid lifecycle: passed, 65 tests.
- Full Call V2: passed, 2309 tests.
- Foreground recovery: passed, 3 tests.
- iOS RunnerTests: passed, 17 tests.
- Dart format check: passed, 6 files unchanged.
- `git diff --check`: passed.

The full suite's historical worktree-isolation tests initially identified the
pre-existing untracked `docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md`. That file was
left untouched. It was temporarily excluded through local Git metadata only
for the decisive suite run, then the exclusion was removed.

Flutter tooling transiently rewrote `pubspec.lock`; it was restored. Neither
`pubspec.yaml` nor `pubspec.lock` is changed.

## Files Changed

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`
- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/real_flow/call_v2_exact_callkit_ownership_test.dart`
- `test/call_v2/real_flow/call_v2_notification_ownership_test.dart`
- `test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart`

## Scope Check

No accepted Firestore authority or transaction logic, Firestore schema/rules,
Navigator architecture, PushKit presentation policy, watchdog duration, Agora
RTC/token/channel logic, Firebase/backend/Cloud Functions, package versions, or
Flutter version changed. No deployment, Firebase operation, or TestFlight build
was performed.

This implementation is ready for source review. Physical repeat-call testing
is still required; no physical-fix claim is made.

## Next

Review `d04d2d6b5d6eb5e2357930a532b6cc7611fea3d7`, then install that exact build
on both physical iPhones and repeat Call A end -> immediate Call B acceptance.
