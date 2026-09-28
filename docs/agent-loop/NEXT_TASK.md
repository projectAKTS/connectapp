# Active Task — Exact Per-Call CallKit Ownership Correction

Branch: `call-v2`

Starting SHA: `b766f93f94b38142fcf49fc2c6ac2c9b38a4df06`

## Goal

Enforce exact per-call native CallKit ownership so cleanup and state changes for
Call A cannot manipulate Call B's CallKit instance.

This is a narrow ownership correction. It does not authorize broader call-flow,
accepted-recovery, routing, RTC, backend, or deployment changes.

## Authorized Scope

1. Preserve the exact accepted native CallKit UUID through:
   `AppDelegate -> NotificationService -> CallSessionManager -> _CallSession ->
   AgoraCallScreen`.
2. When an exact accepted UUID exists, make `AgoraCallScreen` use it unchanged
   instead of reconstructing identity from `inviteId` or `channel`.
3. Remove process-wide `endAllCalls()` behavior from normal per-call
   `AgoraCallScreen` teardown.
4. Make normal Call A teardown terminate only Call A's exact native CallKit
   instance and never an unrelated Call B.
5. Protect exact cleanup from `flutter_callkit_incoming 3.0.0` process-global
   `isFromPushKit` / `self.data` redirection, including when B PushKit has
   replaced plugin-global state before late A cleanup.
6. For already accepted incoming PushKit calls, prevent Helperly's use of plugin
   `setCallConnected()` from synthesizing another native `CXAnswerCallAction` /
   `ACTION_CALL_ACCEPT`.
7. Narrow hard-reset and stale-native cleanup so A cannot classify a currently
   presented, pending, accepted, or otherwise owned B as stale.
8. Preserve cleanup of a truly orphaned native call where lack of ownership is
   safely proven.
9. Re-check exact identity and generation after asynchronous A cleanup awaits so
   a late A completion cannot mutate B.
10. Scope stored accepted-recovery cleanup to the exact accepted identity when
    required to preserve per-call ownership.

## Required Invariants

- An accepted incoming screen receives and owns the exact native CallKit UUID.
- Legacy or outgoing paths without an exact accepted UUID retain their existing
  normalized fallback behavior.
- Normal screen teardown performs exact per-call cleanup only; it does not end
  all native calls or enumerate and terminate unrelated calls.
- Helperly-owned exact native termination acts on the requested UUID regardless
  of plugin-global PushKit state.
- An already accepted incoming call is not re-answered through plugin
  `setCallConnected()`.
- Pending, presented, accepted, routed, or otherwise owned newer calls are
  protected from older-call reset and stale sweeps.
- Every post-`await` cleanup mutation remains bound to the original exact call
  identity and lifecycle generation.
- Exact native route acknowledgement behavior remains unchanged: acknowledge
  only after successful route opening and with the exact accepted UUID.

## Authorized Files

Modify only files strictly required under:

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart` only for exact cleanup scoping or an
  existing native exact-end boundary
- `ios/Runner/AppDelegate.swift` only if a narrow Helperly-owned exact-end
  method is required
- `ios/RunnerTests/RunnerTests.swift` when native code changes
- focused files under `test/call_v2/**`

Do not patch `flutter_callkit_incoming` or files in `.pub-cache`.

## Strict Non-Goals

Do not change:

- Firestore accepted authority architecture
- `_acceptInviteTransactionWithRetry()`
- Firestore schema or security rules
- NotificationService accepted-generation architecture, except exact cleanup
  scoping strictly required by ownership
- Navigator architecture
- PushKit incoming presentation semantics
- native watchdog timeout
- Agora token generation or channel derivation
- Firebase backend or Cloud Functions
- dependency or package versions
- Flutter version
- `flutter_callkit_incoming` package source
- deployment or TestFlight configuration

Do not increase timeouts, deploy, build TestFlight, or claim the historical or
physical repeat-call failure is fixed.

## Required Tests

1. Exact accepted UUID reaches `AgoraCallScreen` unchanged.
2. Exact accepted UUID wins when it differs from normalized invite fallback.
3. Legacy/outgoing paths without an exact UUID retain fallback behavior.
4. Normal per-call cleanup does not invoke global `endAllCalls()`.
5. Normal Call A cleanup ends exact UUID A only.
6. B becoming native-active during A cleanup cannot be ended by A.
7. Plugin-global PushKit state changing to B cannot redirect Helperly exact
   cleanup of A.
8. A hard reset or stale sweep cannot end pending or accepted B.
9. A truly stale orphan remains cleanable through explicit stale recovery.
10. Accepted incoming screen setup does not invoke the plugin path that
    synthesizes a second Accept.
11. A normal end followed immediately by B preserves B's exact UUID and native
    ownership.
12. A -> B -> C sequential calls keep distinct exact ownership and clean only
    their own native calls.
13. Delayed A cleanup completion cannot mutate B.
14. Exact native route acknowledgement remains after successful Navigator push
    only and uses the exact UUID.

If native code changes, add RunnerTests proving exact native termination and
its immunity to unrelated plugin-global state.

## Validation

Run and pass after implementation:

```bash
flutter analyze
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

Also run focused NotificationService, CallSessionManager, and
`AgoraCallScreen`/call-screen ownership tests. Run iOS RunnerTests if native
code changes.

Verify `pubspec.yaml`, `pubspec.lock`, package versions, backend files, and
deployment configuration remain unchanged.

## Physical Acceptance

Physical repeat-call acceptance remains a later review step using matching
builds and configuration on both phones. This implementation task must not
claim physical success from source or automated tests alone.
