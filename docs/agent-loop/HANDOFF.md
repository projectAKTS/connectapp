# Complete Terminal Route Reliability Handoff

STATUS: `ready_for_review`

STARTING_SHA: `dd0a6db86b94ec8ce210d588bb6679aa33f22793`
AUTHORIZATION_SHA: `c27fc45af20366baa1a37ed48167b58635f852bb`
IMPLEMENTATION_SHA: `41586585ee0e293e5dba909a548cea74ac36a710`
ENDING_SHA: `SELF`

## Retained Physical Evidence

The retained native and Flutter diagnostics from the physically stuck receiving
call were recovered from `/private/tmp/helperly-terminal-deadlock-evidence-20261022`.
They show a healthy native presentation/accept path, route-owned and media-owned
ACKs, Agora join, and exact native terminal completion. The final durable Flutter
event was lifecycle inactive; route-pop stages were not persisted by that build.

Relevant UTC sequence:

- `23:49:09.421` native CallKit presented.
- `23:49:11.288` native Accept callback executed.
- `23:49:11.292` native-to-Flutter Accept dispatch completed.
- `23:49:12.855` native route-owned ACK.
- `23:49:13.778` native media-owned ACK after Agora join.
- `23:49:15.329` native terminal observed.
- `23:49:15.330` exact native CallKit call ended.

The physical observation was that audio stopped and `Call ended` remained visible
for more than 40 seconds. Runtime evidence proves native/RTC terminal work but does
not contain the missing route-pop decision. The route failure ordering is proven by
the unchanged-baseline RED regressions below, not inferred from absent logs.

## Proven Root Causes

The previously accepted `clearStaleUiFlags()` correction remains intact. This
investigation found three additional permanent terminal-route paths:

1. If another Navigator route covered terminal Call A when its one-shot auto-close
   fired, `_returnToAppAfterCall()` returned `route_pop_not_current_blocked`. No
   later event retried removal after the covering route closed.
2. If exact manager route/session ownership was detached before the terminal timer,
   `_returnToAppAfterCall()` returned `route_pop_stale_owner_blocked`, even though
   the mounted widget still had exact Call A route identity. No retry existed.
3. A transient exception at the final asynchronous Navigator boundary escaped the
   one-shot close future and permanently abandoned the terminal route.

These are source-level asynchronous route-liveness defects. The retained evidence
does not prove which one occurred on the physical device.

## Baseline RED And Identical GREEN

The following tests failed against the unchanged authorized checkpoint before the
production correction, then passed unchanged after it:

- `terminal Call A covered during auto-close removes only its exact route`
- `detached terminal route still removes itself within two seconds`
- `terminal route retries after one final navigation boundary exception`

The first baseline emitted `route_pop_not_current_blocked`; the second emitted
`route_pop_stale_owner_blocked`; the third surfaced the controlled final-boundary
exception. All three left the terminal route mounted beyond the strict 2,000 ms
simulated-time budget.

## Production Correction

`AgoraCallScreen` now distinguishes exact terminal-route disposal from ordinary
nonterminal navigation:

- A current, still-owned terminal route uses the existing managed `Navigator.pop`.
- A covered or manager-detached terminal route removes only its own captured
  `ModalRoute`; it never pops the current covering/newer route.
- Exact route and Navigator identity are revalidated after the asynchronous final
  boundary.
- A bounded eight-attempt, 100 ms retry handles transient final-boundary failures.
  The existing one-second terminal display remains, so the maximum asserted
  terminal-to-disposal budget is 2,000 ms.
- Firestore, Agora, CallKit, and engine teardown remain background single-flight
  work and are not awaited before route disposal.

`CallSessionManager.handleExactCallRouteRemoved()` completes manager ownership only
when invite, lifecycle generation, and exact accepted CallKit identity still match.
A late Call A completion is therefore a no-op when Call B owns the manager.

`NotificationService` gained inert test-boundary injection for iOS platform and
`activeCalls()`. Tests now execute the actual production Dart stale-native
reconciliation function instead of invoking only its manager call site.

## Terminal Interleaving Coverage

The deterministic suite covers foreground remote terminal, paused/resumed terminal,
native-end-before-Firestore, Firestore-before-native reconciliation, reconciliation
before and during final pop, manager owner detachment, current-session detachment,
delayed Firestore terminal work, delayed cleanup, covered/non-current routes,
duplicate terminal delivery, one-time Navigator failure, audio and video terminal
routes, incoming accepted audio ownership, outgoing local hangup, rapid Call B
during Call A teardown, and late Call A callbacks after Call B ownership.

Key isolation proof:

- `terminal Call A exact removal cannot dismiss owned Call B` delays A at the final
  boundary, transfers manager ownership to B, then releases A. Only A's exact route
  is removed; B remains current and its lifecycle generation/route owner remain
  unchanged.
- `duplicate terminal delivery disposes the route exactly once` preserves one
  authoritative terminal transition.
- `stale native reconciliation during auto-close keeps exact owner until prompt
  route disposal` executes actual NotificationService reconciliation while final
  pop is paused.

## Media And Native Cleanup

No Agora, physical-media, CallKit, watchdog, Firestore authority, or cleanup-gate
implementation changed. Background-audio, notification ownership, rapid/repeated
lifecycle, foreground recovery, exact native CallKit ownership, and full-suite
regressions remain green. Native RunnerTests verify exact CallKit end/watchdog and
sequential identity behavior independently of Flutter route disposal.

## Validation

- Terminal route ownership file: passed, 31 tests.
- Focused cross-area matrix: passed, 201 tests.
- Foreground recovery: passed, 3 tests.
- Full Call V2 suite: passed, 2,386 tests.
- iOS RunnerTests: passed, 30 tests on iOS 26 simulator.
- `flutter analyze`: passed, no issues.
- Format check: passed, 4 files unchanged.
- `git diff --check`: passed.
- Dependency diff: none.

The first two RunnerTests attempts on the iOS 18.5 simulator aborted the host app
before XCTest connected and executed zero tests. The identical suite passed on the
matching iOS 26 simulator with normal simulator signing. No native file changed.

Legacy phase-isolation tests enumerate every untracked file. For the full suite,
the four pre-existing untracked Aider/architecture artifacts were preserved outside
the worktree and restored afterward. Before/after SHA-256 manifests match exactly.

## Files Changed

Implementation/test commit:

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/real_flow/call_v2_route_ownership_terminal_transition_test.dart`

Agent-loop metadata:

- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Scope And Limitations

No backend/Firebase deployment, TestFlight build, physical call, dependency change,
native source change, Agora/RTC behavior change, CallKit behavior change, PushKit
change, Firestore protocol change, or timeout increase occurred.

The tests prove source behavior under deterministic Flutter/iOS simulator models.
They do not establish measured device latency or claim the historical physical
failure is fixed.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review the complete terminal-route reliability correction and deterministic race
matrix before authorizing any TestFlight or physical validation.
