# Active Task - Accepted Call Continuation Stale-Authority Correction

Branch: `call-v2`

Starting SHA: `6c6173148dfc6e9454dec801f911117b2eacd464`

## Physical Evidence

Call 1 reaches accepted ownership, route open, RTC join, and normal terminal
cleanup. A duplicate native Accept for Call 1 arrives after route ownership.
Without restarting the process, distinct Call 2 reaches the Flutter native
accept bridge but never records accepted ownership or attempts a route. The
independent native watchdog later ends Call 2 correctly.

## Goal

Trace the complete accepted-call recovery path and identify the concrete stale
future, guard, identity, or generation authority that blocks Call 2. Implement
the narrowest identity-scoped correction proving that a terminated call cannot
block a later distinct exact CallKit acceptance while same-call duplicates stay
idempotent.

## Allowed Files

- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `lib/call_v2/diagnostics/**` only for narrowly useful safe checkpoints
- relevant `test/call_v2/**` accepted-recovery tests
- `test/notification_foreground_recovery_test.dart`
- `docs/agent-loop/**`

Native iOS files may be changed only if root-cause analysis proves a tiny
identity correction is indispensable. Do not change watchdog timing or
termination semantics.

## Required Invariants

- A newly accepted exact CallKit identity cannot be blocked by terminated-call
  recovery state.
- Duplicate delivery for the same exact identity is idempotent and cannot create
  a second route or persistent recovery lifecycle.
- Terminal teardown releases every call-scoped recovery future, retry, pending
  payload, ownership claim, and generation.
- A stale completion cannot mutate or suppress a newer accepted call.
- Each distinct accepted call has at most one route and one RTC setup owner.
- Native route-owned ACK semantics remain unchanged and occur only after route
  push succeeds.

## Required Regression Proof

- Duplicate Accept after Call A route open.
- Normal terminal teardown releases A recovery authority.
- Distinct Call B immediately acquires accepted ownership and opens once in the
  same process.
- Three sequential calls remain independently routable.
- Delayed completion from A cannot suppress or mutate B.
- Terminal during readiness retry cancels only the owned generation and permits
  the next exact identity immediately.

## Validation

```bash
flutter analyze
flutter test <focused accepted-recovery regression tests> --no-pub
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
flutter test <relevant CallSessionManager/NotificationService tests> --no-pub
git diff --check
```

Run iOS `RunnerTests` only if executable native code changes. Do not deploy or
build TestFlight. Do not claim physical success before the three-call real-device
acceptance gate passes.
