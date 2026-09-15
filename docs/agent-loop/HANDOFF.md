# Review Handoff

Phase: `accepted_call_identity_provenance_exact_end_release`
Status: `ready_for_review`
Starting SHA: `2955bb7c18f4432c036d2c1ad65c18c4378f3499`
Implementation commit: `1dba44fe8c24274e6063cf55374e483754f56d7c`
Ending SHA: `SELF`

## Root Cause

The process-local incoming identity design was correct, but one wiring boundary
did not uphold the stronger invariant claimed by the prior handoff:
`nativeCallEndVerified` notified Flutter through `callkitNativeSafetyTerminated`
without directly releasing the matching live
`CallV2NativeCallkitIdentityAllocator` ownership. Release could still happen via
terminal presentation-state marking, but exact-end verification itself did not
guarantee release if no separate terminal callback arrived.

## Fix

- In the native route safety watchdog `exactEndVerified` callback, release the
  exact CallKit ID from `CallV2NativeCallkitIdentityAllocator`.
- Keep the existing terminal-state release path intact.
- Preserve idempotency: both terminal marking and exact-end verification may
  safely call `release(exactId:)`; unrelated live presentation identities are
  not cleared.
- Notify Flutter with `callkitNativeSafetyTerminated` after the exact live
  identity release.

## Regression Test

- `testWatchdogVerifiedEndReleasesLiveIdentityBeforeNextIncoming`: exercises
  watchdog timeout -> exact end request -> end verification -> callback releases
  allocator ownership -> same logical key allocates fresh UUID B. The test does
  not manually release ownership outside the watchdog verified-end callback.

## Validation

- iOS RunnerTests:
  `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'`
  passed, 16 tests.
- `flutter analyze`: passed, no issues.
- `git diff --check`: passed.
- Flutter tooling transiently rewrote `pubspec.lock`; it was restored. No
  dependency files remain changed.

## Files Changed

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`

## Scope Check

No changes were made to Agora RTC/token/App ID architecture, engine cleanup,
Navigator architecture, PushKit/CallKit presentation ownership, Firebase/backend
functions, Firestore schema/rules, dependency versions, rollout settings,
watchdog timeout duration, deployment settings, or TestFlight. This handoff does
not claim the physical issue is fixed.
