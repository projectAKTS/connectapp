# Media-Owned ACK Ordering Revision Handoff

STATUS: `ready_for_review`

STARTING_SHA: `76eca6691d219abbf1a1a7cde411c76332ab02a3`
ACCEPTED_CHECKPOINT_SHA: `3e9628d8d224a5f7cb1667874e10211554b4fc23`
IMPLEMENTATION_SHA: `7683578ac5a83fc4b8524173294a3c285c73d44a`
ENDING_SHA: `SELF`

## Review Blocker

`CallSessionManager._handlePhysicalMediaJoinSuccess()` previously awaited
`reportAgoraJoinSuccess()` before acknowledging exact native media ownership.
Because that report performs Firestore progress work, a successful Agora join
could remain eligible for the native no-owner watchdog while the network call
was blocked.

## Corrected Ordering

After actual Agora `onJoinChannelSuccess`:

1. Validate the exact current physical media key and lifecycle generation.
2. Acknowledge the exact accepted native CallKit identity, when present.
3. Revalidate exact media/session ownership after the acknowledgment await.
4. Transfer only the still-matching accepted-native watch to media ownership.
5. Run the unchanged manager/Firestore `reportAgoraJoinSuccess()` path.

The Firestore progress report remains required. Its latency no longer leaves an
already joined, exactly owned call eligible for the native ownership watchdog.
No route-owned acknowledgment is fabricated.

## Deterministic Race Proof

`media ACK and watch transfer precede blocked Firestore join progress` blocks
the join-progress path on a `Completer`. While it is blocked, the test proves:

- exactly one native media acknowledgment has completed;
- the exact accepted-native watch is media-owned;
- the shortened watch deadline does not fire;
- no route acknowledgment exists.

After progress is released, the authoritative invite reaches
`calleeStage: joined_local` with no duplicate media acknowledgment.

`stale media key before join success sends no media ACK` replaces Call A with
Call B before A's delayed join callback. It proves A emits no acknowledgment
and cannot mutate B.

`late media ACK completion cannot transfer or mutate newer call` blocks A's
native acknowledgment, installs B, and then releases A. It proves the late A
completion cannot transfer a watch, report A joined, or mutate B.

## Files Changed

- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_background_audio_media_integration_test.dart`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

The pre-existing untracked
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` remains untouched. Its SHA-256 before
and after full-suite isolation was
`d33b3bf300a4980807b863d6c4b29465548284b1c6004638dcfa7fbcb2eda0f3`.

## Validation

- Focused background audio integration: 7 passed.
- Physical media owner: 11 passed.
- Route ownership: 14 passed.
- Exact CallKit ownership: 14 passed.
- Notification ownership: 38 passed.
- Rapid lifecycle: 65 passed.
- Repeated lifecycle: 50 passed.
- Foreground recovery: 3 passed.
- Full isolated Call V2 suite: 2,346 passed.
- iOS RunnerTests: 26 passed, 0 failed.
- `flutter analyze`: passed with no issues.
- `git diff --check`: passed.
- Dependency diff: none for `pubspec.yaml`, `pubspec.lock`, `ios/Podfile`, or
  `ios/Podfile.lock`.

Historical path-isolation tests enumerate repository paths. During the final
full-suite run, the in-progress agent metadata and pre-existing untracked
architecture document were preserved outside the repository and restored
byte-for-byte immediately afterward.

## Scope

No physical media owner/runtime architecture, screen attachment, widget detach,
video or outgoing-audio route-first behavior, CallKit activation latching,
native watchdog duration, route-owned acknowledgment, accepted transaction,
route/redial ownership, PushKit/APNs, native code, backend, or dependency was
changed. No backend/Firebase deployment or TestFlight build was performed.

This handoff does not claim physical validation or that the physical issue is
fixed.

## Next

Review the focused ordering correction and automated evidence before any
TestFlight or physical validation.
