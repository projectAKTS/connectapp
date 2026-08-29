# Review Handoff

Phase: `physical_repeat_call_pending_accept`
Status: `ready_for_review`
Remote checkpoint: `318a6aac3994bde2e7726ba59ed2aa81563c6fa9`
Authorized baseline: `6b548b2f4ade470e4b8b02fae9d5517ee0438ec9`
Implementation commit: `4c6db2dc3380d9383a756d61ffe0ac8ac529d8c9`

## Root Cause

After native CallKit Accept, accepted route ownership could remain pending with
no routed Flutter session. That state had no independent authoritative terminal
observer or absolute cleanup deadline. If routing never succeeded, a remote
terminal transition could leave the actual accepted native CallKit session
active indefinitely. Cleanup could also target a reconstructed identifier, and
an in-flight acceptance coroutine could re-mark native state after terminal
cleanup began.

## Correction

- Preserves the actual CallKit identifier carried by the existing native and
  plugin acceptance bridges; reconstruction is only a fallback when no exact
  identifier exists.
- Adds one exact-invite, lifecycle-generation accepted-native route watch when
  accepted ownership exists but the route has not opened.
- The watch owns a direct authoritative invite listener and an independent
  20-second watchdog. It does not depend on Navigator readiness, app resume,
  Agora startup, or an active routed session.
- Missing, declined, missed, cancelled, ended, or failed authoritative state
  invalidates pending ownership, cancels readiness and watcher resources, clears
  stored recovery, ends the exact native call, verifies it is absent, and
  returns the lifecycle to reusable idle state.
- Watchdog expiry rereads authoritative state and guardedly fails a still-live
  unrouteable invite before performing the same exact native cleanup.
- Exact native cleanup performs one end request, a bounded active-call
  verification, and one exact-ID escalation if the matching native call remains.
- Listener cleanup never awaits cancellation of its own subscription, avoiding
  self-cancellation deadlock.
- Successful route opening atomically transfers ownership by canceling the
  pending listener/watchdog before normal routed lifecycle ownership continues.
- Terminal cleanup publishes ending/teardown before asynchronous cleanup and
  acceptance now rejects ending, teardown, or idle generations, preventing late
  callbacks from restoring accepted state.
- Sign-out, hard reset, pending supersession, and route-readiness deadline paths
  dispose the exact pending-native owner.

## AppDelegate Review

`AppDelegate.swift` is unchanged. The accepted checkpoint already sends
`call.data.uuid` as `callkitId` in `callkitAcceptedNative` and stores it as
`lastCallkitAcceptedCallkitId`. The existing native state bridge preserves a
canonical UUID, so no native presentation or ownership change was necessary.

## Regression Resolution

The focused full-file regression was an obsolete test timing assumption. The
new terminal listener resolves ownership immediately, so a later explicit
resume correctly returns `invalid` instead of being the operation that first
returns `terminal`. Fake-time tests were minimally synchronized with listener
attachment, canceled readiness delay, reset delay, and intentional watcher
disposal. Production guarantees were not weakened.

## Tests

- Exact native identifier is preserved and exact cleanup never uses the
  reconstructed fallback when the accepted ID is available.
- Remote declined, cancelled, ended, failed, and missed states end the exact
  native call without Navigator, clear ownership/recovery, and remain reusable.
- Independent watchdog fails a live unrouteable invite, verifies exact native
  removal, and exercises one controlled exact-ID escalation.
- Terminal-listener cleanup settles without self-cancellation deadlock.
- Route-open transfer prevents a stale pending watcher from ending the routed
  call; terminal ownership prevents a concurrent late route open.
- Native/plugin duplicate accepts converge on one owner and one outcome.
- Sign-out and hard reset end exact pending native ownership.
- Twenty sequential cycles alternate successful route transfer, remote terminal
  cleanup, and watchdog cleanup with expected route/RTC counts and no stale
  native calls.

## Validation

- `flutter analyze`: passed, no issues.
- `flutter test test/call_v2 --no-pub`: passed, 2,274 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`:
  passed, 3 tests.
- Focused notification ownership file: passed, 29 tests.
- Focused rapid lifecycle-manager file: passed, 57 tests.
- `git diff --check`: passed.

## Safety

No `AppDelegate.swift`, engine cleanup coordinator, Agora/RTC/token code,
Firebase/backend code, Firestore rules, or deployment configuration changed.
No Firebase service was contacted, no TestFlight build was created, and nothing
was deployed.

## Physical Follow-up

Install the pushed branch tip on both iPhones and repeat the exact Call 1 then
background Call 2 native Accept scenario. Verify that Call 2 either opens its
single Flutter route or its exact native CallKit session ends automatically when
the remote invite terminalizes or the pending-route watchdog expires.
