# Review Handoff

Phase: `accepted_call_continuation_stale_authority`
Status: `ready_for_review`
Starting checkpoint: `6c6173148dfc6e9454dec801f911117b2eacd464`
Implementation commit: `f4ed3bfedd922ecfddc2d25ed3c63cf0597e0625`
Ending SHA: `SELF`

## Root Cause

- `NotificationService` used one process-global `_recoveringAcceptedCall` flag,
  one mutable pending payload, one retry timer, and one readiness future without
  exact accepted-call ownership.
- A duplicate Accept for routed call A could start another asynchronous recovery.
  While A remained in flight, distinct Accept B reached the Flutter bridge, saw
  the global guard, replaced the shared pending payload, scheduled a synthetic
  network retry, and returned before `CallSessionManager` recorded B ownership.
- A's later completion, unconditional `finally`, or unscoped stored-recovery
  clear could then cancel or overwrite B's shared recovery state. Call 1 worked
  because no older recovery owned the guard; the duplicate A delivery created
  the stale authority that could suppress Call 2 before
  `acceptedOwnershipRecorded`.

## Fix

- Accepted recovery now has an exact identity owner and monotonic generation.
  Same-call duplicates coalesce; a distinct explicit native Accept immediately
  acquires a newer generation and cancels only the previous generation's retry.
- Results, errors, retry callbacks, readiness futures, and `finally` cleanup
  mutate state only while their exact identity and generation still own it.
- `CallSessionManager` independently generation-guards each recovered Accept
  across asynchronous payload and Firestore reads, so stale A cannot act after B
  has claimed manager authority.
- Stored accepted recovery clearing now carries call identity. A stale clear for
  A cannot erase current B ownership. Sign-out/dispose still invalidate all
  recovery state intentionally.
- Existing route/lifecycle arbitration remains the one-route/one-RTC-owner
  boundary. Native route-owned ACK is still emitted only after a successful
  route push.
- Four safe diagnostic stages were added between Flutter bridge receipt and
  accepted ownership. The copied report still contains no raw identifiers.

## Regression Proof

- `delayed duplicate A completion cannot suppress distinct accepted B` models
  routed A, delayed duplicate A recovery, normal A teardown, exact B Accept,
  then stale A completion. B records ownership and opens once; A cannot schedule
  a retry or alter B.
- `three sequential exact accepted calls route once per identity` runs A, B,
  and C in one service/manager process, including duplicate Accept delivery.
  Each call opens exactly one route and one RTC setup owner, and terminal cleanup
  releases the preceding accepted-recovery owner.
- `terminal accepted retry releases its generation before next exact call`
  proves an A network retry resolves terminal, releases only A, and B can start
  immediately without service reconstruction.
- Existing focused tests continue to prove same-call duplicate idempotency,
  accepted ownership, route-open ACK timing, lifecycle teardown, sign-out, and
  foreground/background recovery.

## Validation

- `flutter analyze`: passed, no issues.
- `flutter test test/call_v2/real_flow/call_v2_notification_ownership_test.dart --no-pub`:
  passed, 33 tests.
- `flutter test test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart --no-pub`:
  passed, 57 tests.
- `flutter test test/call_v2/diagnostics/call_v2_physical_diagnostic_ledger_test.dart --no-pub`:
  passed, 5 tests.
- `flutter test test/call_v2 --no-pub`: passed, 2,286 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`:
  passed, 3 tests.
- `git diff --check`: passed.
- iOS RunnerTests were not required because no executable native code changed.
- The local Flutter resolver transiently rewrote five lockfile entries during
  analysis; `pubspec.lock` was restored and dependency files are unchanged.

## Files Changed

- `integration_test/call_message_stability_test.dart`
- `lib/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/real_flow/call_v2_notification_ownership_test.dart`
- `test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart`

## Scope Check

No changes were made to Agora, PushKit presentation, native safety-watchdog
semantics or duration, global Navigator architecture, Firebase callable/backend
architecture, Firestore schema/rules, dependencies, or iOS native code. Nothing
was deployed and no TestFlight build was created. This is source-level
`ready_for_review`; it does not claim the physical repeat-call defect is fixed.

## Physical Acceptance Gate

Install the reviewed branch tip on both real iPhones and run three immediate
sequential calls without force quit. Each call must show one CallKit Accept, one
Flutter route, one RTC owner, two-way media, and normal terminal cleanup.
