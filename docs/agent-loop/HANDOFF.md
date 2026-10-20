# Final Fast Hangup Safety Revision Handoff

STATUS: `ready_for_review`

STARTING_SHA: `15828dbc5fdd94e69d0d75d15359ecc63e930b45`
AUTHORIZATION_SHA: `dc5b42ba8fdd742a4ff4b627286922334361b26f`
IMPLEMENTATION_SHA: `6466cfc954e6feaa8f69af56aea62013e3ce35ae`
ENDING_SHA: `SELF`

## Final Pre-Pop Guard

`AgoraCallScreen._returnToAppAfterCall()` now performs one final synchronous
validation after the last diagnostic/test asynchronous boundary and immediately
before navigation. It verifies the exact managed session ownership (invite,
lifecycle generation, and accepted CallKit identity), exact route owner, the
same `ModalRoute`, the same `NavigatorState`, and that the route is still
current. No await exists between this validation and `Navigator.pop()` (or the
root fallback).

The deterministic production-Navigator regression pauses Call A at this final
boundary, transfers manager and Navigator ownership to Call B, then releases A.
A returns stale without popping B; B remains current, route-active, and owned by
its newer lifecycle generation.

## Prompt Owned Media Teardown

Valid local hangup still establishes authoritative ending ownership first.
Immediately afterward it starts exact physical-media-owner termination and the
screen engine cleanup without waiting for the Firestore terminal transaction.
Exact CallKit UI cleanup also starts independently. The mandatory Firestore
transition remains active and is awaited before exact hard reset.

`CallSessionManager.beginOwnedPhysicalMediaTeardown()` accepts only the exact
current session and lifecycle generation. It snapshots the session's exact
physical media key and caches one teardown future, making duplicate local,
remote-terminal, screen-disposal, and late callback cleanup idempotent. A late
Call A key cannot terminate Call B.

For shared route-first audio, the runtime enters the existing process cleanup
gate as soon as exact owner termination starts. While that cleanup is held, the
old physical owner remains present and a different call cannot claim media.
Only completion releases that ownership. Existing cleanup-coordinator tests
prove failed cleanup keeps the next-engine decision blocked.

## Deterministic Proof

- The production hangup control is exercised while the authoritative terminal
  transaction is held by a `Completer`.
- Home becomes visible while both Firestore completion and physical-runtime
  cleanup remain held.
- The exact audio runtime has already made media inactive, but its owner remains
  held, preventing replacement until cleanup completes.
- Releasing media cleanup clears only A's exact owner while Firestore is still
  held; releasing Firestore then completes terminal/native cleanup.
- Exact native CallKit cleanup starts independently and the manager's terminal
  path removes the matching native call after the authoritative transition.
- Existing failure regressions prove cleanup failure still attempts CallKit and
  session cleanup while retaining `cleanup_failed` next-engine blocking.
- Existing sequential integration proves Audio A -> Audio B -> Video C retains
  one route and one RTC owner per call after cleanup completes.

## Files Changed

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_background_audio_media_integration_test.dart`
- `test/call_v2/real_flow/call_v2_physical_media_owner_test.dart`
- `test/call_v2/real_flow/call_v2_route_ownership_terminal_transition_test.dart`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/STATE.json`

The pre-existing untracked architecture document and Aider artifacts remain
untouched.

## Validation

- Core changed-file regression set: 44 passed.
- Focused cleanup/ownership/recovery/lifecycle matrix: 223 passed.
- Foreground recovery: passed within the focused matrix.
- Audio A -> Audio B -> Video C: passed within the focused matrix.
- Full Call V2 suite at exact implementation commit: 2,373 passed.
- `flutter analyze`: passed, no issues.
- Formatting check: passed.
- `git diff --check`: passed.
- Dependency diff: none.

The full suite ran in a detached clean worktree at the exact implementation
commit because legacy source-isolation audits reject preserved untracked files.

## Scope And Safety

No Agora connection setup, tokens, backend, Firestore acceptance semantics,
PushKit/APNs, native CallKit implementation, video/camera setup, audio join
timing, cleanup timeout, cleanup-gate policy, dependency, or build flag changed.
No TestFlight build, deployment, backend contact, or physical call occurred.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review this narrow safety revision before authorizing any physical validation.
