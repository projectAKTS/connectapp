# Review Handoff

STATUS: `ready_for_review`

STARTING_SHA: `e871a8bb70d06ac4c29efa616bf41f9d12d97276`
IMPLEMENTATION_SHA: `9645d97e97257ded381e770b61c72f861ed38b04`
ENDING_SHA: `SELF`

## Root Cause

The confirmed physical failure boundary moved after
`acceptedOwnershipRecorded` and before `routeAttemptStarted`.

Most likely root cause class from source evidence: **A. NETWORK READ FAILURE**.

Exact source evidence:

- `CallSessionManager.handleRecoveredAcceptedInvite()` records accepted
  ownership, then calls `_readInviteData(bridgePayload.inviteId)`.
- If that read throws, the method returns
  `AcceptedCallRecoveryResult.pendingNetwork` before `_acceptInviteAndOpen()`,
  so no `routeAttemptStarted`, `navigatorReady`, `routeOpened`, or
  `rtcSetupStarted` can appear.
- `resumePendingAcceptedRouteIfReady()` follows the same authoritative
  verification boundary through `_resumeAcceptedRouteContinuation()`.
- `FirestoreReadHelper.getDoc()` uses `Source.serverAndCache` with the manager's
  5 second timeout, then attempts a 2 second `Source.cache` fallback, and
  triggers non-destructive `enableNetwork()` recovery on recoverable failures.
- Caller-side invite creation uses a fresh `callInvites` auto-ID document and
  initializes `status`, `callerStage`, `calleeStage`, `endReason`, and `endedBy`.
  The current production path does not intentionally reuse the same invite
  document for sequential calls.

This change does not claim the physical issue is fixed. It adds the missing safe
trace so the next physical run can prove whether Call 2 is A, B, or C.

## Call 2 Authoritative Read Trace

Added safe diagnostic stages between accepted ownership and route attempt:

- `acceptedAuthoritativeReadStarted`
- `acceptedAuthoritativeReadSucceeded`
- `acceptedAuthoritativeReadPendingNetwork`
- `acceptedAuthoritativeReadTerminal`
- `acceptedAuthoritativeReadOpenable`
- `acceptedContinuationResumeStarted`
- `acceptedContinuationPendingNetwork`
- `acceptedContinuationInvalidGeneration`
- `acceptedContinuationOpenRequested`

These stages contain only stage names/counts/timing through the existing safe
physical ledger. No invite ID, UUID, UID, channel, token, payload, or credential
is rendered.

## Call Document Lifecycle Trace

Tests now prove:

- Fresh Call B authoritative read can see an openable document and route once.
- A reused logical invite document must reset terminal fields before B can be
  considered openable.
- A temporary read failure preserves accepted ownership and later successful
  read opens the same pending call.
- A terminal authoritative read prevents route opening and native cleanup still
  occurs.
- A/B/C sequential calls in one process route once per call with one RTC owner
  count per call.

## Fix

- Added safe physical ledger stages for accepted-route authoritative read and
  continuation outcomes.
- Instrumented all accepted-route verification paths:
  `handleRecoveredAcceptedInvite()`, `_resumeAcceptedRouteContinuation()`, and
  `_continueClaimedPendingIncoming()`.
- Added deterministic regression tests for the physical-shaped boundary without
  changing routing, RTC, native UUID allocation, PushKit/CallKit presentation,
  Navigator architecture, watchdog duration, backend, packages, or deployment.

## Regression Tests

- `accepted pending read trace reaches openable route request for Call B`:
  models Call A teardown then Call B accepted; proves openable read -> route
  request -> route opened.
- `reused invite document must reset terminal fields before B routes`:
  models stale terminal fields on a reused logical document and proves reset
  fields allow B/openable rather than A/terminal.
- `temporary accepted read failure preserves B then later opens`:
  models one recoverable read failure; proves ownership survives and later read
  opens once.
- `terminal ended/cancelled/failed clears pending accepted intent`:
  proves terminal read before claim produces terminal trace and no route.
- `A B C accepted sequence records openable reads and one route each`:
  proves sequential same-process calls get one route and one RTC owner count per
  call.
- Existing lifecycle tests continue covering stale generation invalidation and
  no route/RTC owner on invalidated continuation.

## Validation Counts

- `flutter analyze`: passed, no issues.
- Focused accepted ownership tests:
  `flutter test test/call_v2/real_flow/call_v2_notification_ownership_test.dart --no-pub`
  passed, 38 tests.
- Lifecycle manager tests:
  `flutter test test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart --no-pub`
  passed, 61 tests.
- Full Call V2:
  `flutter test test/call_v2 --no-pub`
  passed, 2295 tests.
- Foreground recovery:
  `flutter test test/notification_foreground_recovery_test.dart --no-pub`
  passed, 3 tests.
- `git diff --check`: passed.

Flutter tooling transiently rewrote `pubspec.lock`; it was restored. No
dependency files remain changed.

## Files Changed

- `lib/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart`
- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart`

## Scope Check

No changes were made to native UUID allocation, PushKit presentation, CallKit
exact identity, Agora, Navigator architecture, watchdog timeout, package
versions, deployment target, Firebase/backend functions, Firestore rules, or
TestFlight. No deployment was performed and no physical-fix claim is made.

## Next

Run one exact physical diagnostic build from this branch and inspect whether
Call 2 reports `acceptedAuthoritativeReadPendingNetwork`,
`acceptedAuthoritativeReadTerminal`, or
`acceptedContinuationInvalidGeneration` before the native watchdog fires.
