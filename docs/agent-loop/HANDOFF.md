# Critical Terminal Screen Deadlock Handoff

STATUS: `ready_for_review`

STARTING_SHA: `b8f29c2836ba9cb0c27fc5bd6b0cb9293d6d0b0b`
AUTHORIZATION_SHA: `d8a24702bad229204a03352cab0f166cc726dd63`
IMPLEMENTATION_SHA: `89dcbd151f9ed5636f40c1f9b3e872b2d50bc37f`
ENDING_SHA: `SELF`

## Physical Evidence Recovered

The existing Venus TestFlight artifacts were copied read-only from build
`1.0.2 (202610211427)`. For the failed call, the native durable ledger records
route ownership, media ownership, terminal observation, and exact native call
end. The Flutter durable ledger records the accepted transaction, physical
media claim, token request, Agora join callback, and media-owned ACK. These
artifacts corroborate that media connected and the exact native call ended, but
they do not persist the later Flutter route-pop decision.

No new physical call was placed. The causal route-pop proof therefore comes
from the deterministic baseline regression below, not from an absent physical
log event.

## Baseline Red Proof

Test:

`remote terminal route returns home after native stale UI reconciliation`

The test uses the real `MaterialApp`, `Navigator`, `PopScope`,
`AgoraCallScreen`, and production `CallSessionManager` methods. It creates an
exact owned callee route, drives `Call ended` through
`reportRemoteOffline()`, then invokes `clearStaleUiFlags()`, the same public
manager method used by `NotificationService` after native active-call
reconciliation reports no CallKit call.

On the unmodified baseline:

- the terminal route was visible and displayed `Call ended`;
- exact route ownership was initially active;
- stale-native reconciliation cleared route-active and route-owner state
  because terminal sessions are excluded from `hasActiveSession`;
- the one-second automatic close reached `route_pop_stale_owner_blocked`;
- Home was absent and `Call ended` remained after the test advanced beyond 40
  seconds;
- no later retry dismissed the route.

The existing terminal widget regression missed this because it used
`managedRouteExitForTest`, explicitly bypassing manager route ownership. Other
tests covered terminal UI, stale cleanup, and route ownership independently,
but never combined remote terminal state, exact real Navigator ownership, and
native stale-UI reconciliation.

## Proven Cause And Fix

The reproduced ownership invalidation point is
`CallSessionManager.clearStaleUiFlags()`, not a normal mounted-route call to
`_detachSessionState()`. Normal terminal signal handling retains a mounted
route, and normal hard reset defers final session cleanup until that route
closes. The supplied `_detachSessionState()` contract was audited, but it was
not needed to reproduce this physical-shape failure.

`clearStaleUiFlags()` previously returned only for a nonterminal active
session. Once remote terminal handling marked the exact session terminal,
`hasActiveSession` became false even though the matching Flutter route was
still mounted. Native CallKit ending then made stale-native reconciliation
eligible to clear the route flags required by `_returnToAppAfterCall()`.

The correction preserves flags only when:

- an active nonterminal session exists;
- a route is currently opening; or
- the active route owner exactly owns the current session.

Mismatched or orphaned UI flags remain clearable. No fallback pop, destructive
navigation, delayed retry, session resurrection, or cleanup bypass was added.

## Green And Isolation Proof

The identical physical-shape regression now retains exact route ownership,
records `route_pop_authorized`, invokes one Navigator pop, disposes the terminal
route, and shows Home. Engine cleanup, exact physical-media teardown, and
CallKit cleanup start independently and remain idempotent.

Existing adversarial coverage remains green for:

- stale Call A screens and delayed callbacks not dismissing Call B;
- final synchronous current-route and exact-owner validation before pop;
- repeated exit requests producing one cleanup/navigation action;
- exact native CallKit ownership and cleanup;
- background accepted audio and accepted recovery;
- physical-media and process cleanup-gate ownership;
- rapid and repeated lifecycle reuse;
- Audio A -> Audio B -> Video C with one media owner per call.

## Files Changed

Implementation commit:

- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_route_ownership_terminal_transition_test.dart`

Agent-loop metadata:

- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

The pre-existing untracked architecture document and Aider artifacts were
preserved unchanged.

## Validation

- Baseline regression: failed before the fix with
  `route_pop_stale_owner_blocked` and no Home after more than 40 seconds.
- Identical corrected regression: passed, 1 test.
- Route ownership file: passed, 20 tests.
- Focused ownership/recovery/media/lifecycle matrix: passed, 215 tests.
- Foreground recovery: passed, 3 tests.
- Full Call V2 suite: passed, 2,374 tests.
- `flutter analyze`: passed, no issues.
- Format check: passed.
- `git diff --check`: passed.
- Dependency diff: none.

Legacy phase-isolation tests enumerate all untracked files. For the final full
suite only, the four pre-existing untracked artifacts were moved to a temporary
directory under an automatic restore trap, then restored. Their final paths and
untracked status are unchanged.

## Scope And Safety

No `AgoraCallScreen` behavior, Navigator architecture, Agora setup or cleanup,
physical-media implementation, CallKit/native code, PushKit/APNs, Firebase,
Firestore authority, backend, timeout, dependency, build flag, or release
configuration changed. No TestFlight build, App Store upload, deployment,
backend contact, or physical call occurred.

ROOT_CAUSE_CONFIDENCE: `SOURCE_PROVEN`

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review the narrow terminal route-ownership correction before authorizing any
physical validation.
