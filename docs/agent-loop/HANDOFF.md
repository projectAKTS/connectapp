# Review Handoff

STATUS: `ready_for_review`

STARTING_SHA: `41f8c89d934c698ef0b297867297f77588d1698f`
IMPLEMENTATION_SHA: `59393f4cb484addf504b880aab0f392a20f4cb33`
ENDING_SHA: `SELF`

## Confirmed Root Cause

Physical instrumentation proved that accepted native recovery repeatedly entered
the standalone authoritative invite read, timed out, fell back to an empty or
unusable cache, and returned `pendingNetwork` before the guarded accept
transaction or route attempt. The accepted flow duplicated Firestore authority:
a server/cache read was required before a transaction that independently read
and validated the same invite.

## Authority Flow

Old:

`native accept -> local ownership -> standalone server/cache read -> guarded
accept transaction -> second standalone read -> route`

New:

`native accept -> local ownership -> guarded accept transaction -> typed
authoritative result/payload -> route`

The existing `_acceptInviteTransactionWithRetry()` remains the single trust
boundary. Its Firestore transaction:

- reads the exact `callInvites` document;
- rejects a missing document;
- requires `toUid` to equal the authenticated current user;
- rejects terminal and unknown statuses;
- permits `ringing`, `accepted`, `joining`, and `connected`;
- requires authoritative channel and caller identity data;
- atomically changes `ringing` to `accepted`; and
- returns the authoritative payload and resulting status used by routing.

## Removed Redundant Reads

- `handleRecoveredAcceptedInvite()` no longer performs a mandatory standalone
  read before accepted continuation.
- `_resumeAcceptedRouteContinuation()` invokes the guarded transaction directly
  until acceptance is confirmed, then reuses its typed result.
- `_acceptInviteAndOpen()` no longer performs a second read after transaction
  success.
- `_continueClaimedPendingIncoming()` sends an already-accepted pending intent
  directly through the same transaction authority path after teardown.

Unaccepted prompt display/validation, fallback presentation, active-state
monitoring, terminal verification, and watchdog deadline reads are unchanged.

## Retry Semantics

Recoverable transaction failures retry the same transaction up to three times,
using the existing short `250 ms * attempt` delay and unchanged transaction
timeout. Lifecycle generation ownership is checked before every attempt and
after injected/asynchronous boundaries. Exhaustion returns `pendingNetwork` to
the existing bounded NotificationService coordinator. Exact native terminal or
watchdog completion invalidates the matching generation, prevents another
transaction attempt, and cannot cancel a newer call.

## Security Invariants

- PushKit payload data alone never authorizes a route.
- Cache data never authorizes accepted recovery.
- Missing, terminal, wrong-recipient, invalid-status, and invalid-payload
  transaction results never open a route or create an RTC owner.
- Route metadata comes from the transaction snapshot; the exact native CallKit
  identity remains attached to the accepted ownership.
- A terminal result awaits the existing native-watch cleanup before recovery
  reports terminal.

## Diagnostics

Added safe stages:

- `acceptedTransactionStarted`
- `acceptedTransactionSucceeded`
- `acceptedTransactionPendingNetwork`
- `acceptedTransactionRejectedTerminal`
- `acceptedTransactionRejectedRecipient`

The physical ledger still contains only safe stage names, sequence/timing data,
booleans, and counters. It exposes no invite ID, UUID, UID, channel, token,
payload, or credential.

## Regression Tests

- `standalone read failure cannot block accepted transaction route` proves an
  injected read timeout is never invoked and the server transaction routes with
  authoritative metadata.
- `accepted transaction retries recoverably then opens one route` proves one
  generation survives a recoverable transaction failure and creates exactly
  one route and RTC owner.
- `accepted transaction rejects wrong recipient without route` proves recipient
  validation remains inside the transaction boundary.
- `stale cached ringing cannot override server terminal state` proves cache
  cannot authorize a terminal server document.
- `native terminal cancels blocked accepted transaction generation` proves
  watchdog/native terminal ownership prevents later retry or route creation.
- `accepted pending transaction reaches authoritative route request for B` and
  the A/B/C accepted sequence prove teardown continuation and sequential reuse
  route once per accepted transaction.
- Notification ownership tests now synchronize duplicate, distinct exact-ID,
  fallback-ID, and terminal-cancellation races at the transaction boundary,
  not the removed read boundary.

## Validation Counts

- `flutter analyze`: passed, no issues.
- Notification ownership: passed, 38 tests.
- Lifecycle manager and transaction authority: passed, 65 tests.
- Physical diagnostic ledger: passed, 5 tests.
- Full Call V2: passed, 2299 tests.
- Foreground recovery: passed, 3 tests.
- `git diff --check`: passed.
- iOS RunnerTests: not run; native code was unchanged.

Flutter tooling transiently rewrote `pubspec.lock`; it was restored. No
dependency files remain changed.

## Files Changed

- `lib/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart`
- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_notification_ownership_test.dart`
- `test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart`

## Scope Check

No native code, UUID allocator, PushKit/CallKit presentation, Navigator
architecture, Agora/RTC code, watchdog timeout, backend/schema, Firestore rules,
dependency, Flutter version, or deployment configuration changed. No backend or
Firebase deployment and no TestFlight build occurred. This is ready for source
review; it is not claimed physically fixed.

## Next

Install one physical diagnostic build from the reviewed branch and verify the
accepted path records `acceptedTransactionSucceeded`,
`acceptedContinuationOpenRequested`, and `routeOpened` before the unchanged
native watchdog deadline.
