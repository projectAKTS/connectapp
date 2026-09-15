# Review Handoff

Phase: `accepted_call_identity_provenance`
Status: `ready_for_review`
Starting checkpoint: `9087e450936aeecbf11c2836ae0e4196065c11b4`
Implementation commit: `8ab6e7fb816c59dfa1b85dd4118112e05220b611`
Ending SHA: `SELF`

## Root Causes

Identity provenance root cause:
Native incoming CallKit identity was still derived from the logical call/invite
shape when the previous presentation had terminalized. In the physical same
invite reuse case, that made a fresh native presentation look like the same
exact CallKit call to Dart, so valid duplicate suppression could coalesce Call B
before accepted ownership.

Ownership latency root cause:
Accepted recovery previously waited for network-backed invite reads before
recording local accepted ownership. A delayed authoritative read could leave the
new accepted CallKit intent without the local owner needed to survive duplicate
signals and recovery retries.

Post-terminal retry root cause:
Native watchdog end verification was terminal for iOS CallKit, but Flutter did
not receive an exact-ID terminal signal. The accepted recovery generation for
that exact native call could therefore remain retryable after native end
verification.

## Fix

- Added a native CallKit identity allocator that generates a fresh exact UUID
  for each new incoming presentation after the previous presentation is no
  longer live, while reusing the existing exact UUID for duplicate callbacks on
  the same still-live presentation.
- Preserved the actual accepted native CallKit UUID through PushKit/native
  accept, NotificationService accepted recovery, CallSessionManager ownership,
  routed session payload replacement, route-pending watches, and terminal
  cleanup.
- Moved local accepted ownership recording before the delayed authoritative
  Firestore read, while retaining the authoritative read before any invalid or
  terminal invite can open the route/RTC.
- Added exact native safety termination notification from Swift to Flutter after
  verified native end, and invalidated only the matching accepted recovery
  generation/watch.

## Invariants

Native UUID invariant:
A new physical incoming presentation receives a fresh exact CallKit UUID after
the previous native presentation is terminal. Duplicate handling for the same
still-live native presentation reuses the existing exact UUID and does not create
a second native call.

Ownership ordering invariant:
Accepted ownership is established before redundant/delayed network waits, but
authoritative Firestore validation still gates route opening. Terminal or
invalid invites cannot route or start RTC.

Terminal cancellation invariant:
Native watchdog verified-end sends an exact-ID terminal/cancellation signal into
Flutter. Only the matching recovery generation and matching native route watch
are invalidated; stale A terminal completion cannot cancel a newer distinct B.

## Regression Tests

- `testNativeIdentityReusesOnlyLivePresentation`: native allocator creates a
  fresh exact UUID for a sequential same-invite presentation and reuses the UUID
  only for a live duplicate presentation.
- `testTimeoutReportsExactEndVerificationOnce`: native watchdog invokes the
  exact end-verification callback once after timeout cleanup.
- `same invite with different exact CallKit IDs is not coalesced`: same invite
  plus UUID A/UUID B remains distinct; invite fallback does not override exact
  mismatch.
- `same invite duplicate exact A does not suppress distinct exact B`: duplicate
  UUID A remains idempotent, then distinct UUID B can still acquire ownership
  and route.
- `native verified terminal cancels exact recovery while authoritative read
  waits`: exact native terminal invalidates the blocked matching recovery before
  the delayed read can keep retrying.
- `terminal accepted retry releases its generation before next exact call`:
  terminal A retry cannot survive into B.
- `same invite routes A B C with fresh exact native identity in one process`:
  A -> B -> C reuse the same invite identity with fresh exact UUIDs, one route
  and one RTC owner per call.
- `native source coordinates APNS fallback and PushKit presentation`: source
  audit proves the AppDelegate bridge uses the fresh/live exact identity helper,
  forwards `call.data.uuid`, and keeps terminal lookup exact.

## Validation

- `flutter analyze`: passed, no issues.
- Focused NotificationService accepted ownership:
  `flutter test test/call_v2/real_flow/call_v2_notification_ownership_test.dart --no-pub`
  passed, 38 tests.
- Focused CallSessionManager lifecycle/identity:
  `flutter test test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart --no-pub`
  passed, 57 tests.
- Full Call V2:
  `flutter test test/call_v2 --no-pub` passed, 2,291 tests.
- Foreground recovery:
  `flutter test test/notification_foreground_recovery_test.dart --no-pub`
  passed, 3 tests.
- iOS RunnerTests:
  `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'`
  passed, 8 tests.
- `git diff --check`: passed.
- Flutter tooling transiently rewrote `pubspec.lock`; it was restored. No
  dependency files remain changed.

## Files Changed

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/real_flow/call_v2_notification_ownership_test.dart`
- `test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart`

## Scope Check

No changes were made to Agora RTC/token/App ID architecture, engine cleanup,
Navigator architecture, Firebase/backend/functions, Firestore schema/rules,
dependency versions, rollout settings, or deployment settings. The native
watchdog timeout was not increased. No TestFlight build was created. This
handoff does not claim the physical issue is fixed.
