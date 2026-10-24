# Persistent Terminal Route Diagnostics Handoff

STATUS: `ready_for_review`

STARTING_SHA: `30a1303da11ee249fc3303319c635286e8fe7f69`
AUTHORIZATION_SHA: `aab9026b0f0171c5d0fda68bd52635d162590514`
IMPLEMENTATION_SHA: `44b95292bf888129f5401c45891f1a011254ec00`
ENDING_SHA: `SELF`

## Durable Route Events

The existing bounded durable recorder now represents the terminal navigation
outcome with these privacy-safe stages:

- `terminalRouteExitRequested`
- `terminalRouteOwnershipRejected`
- `terminalRouteCovered`
- `terminalNavigatorPopRequested`
- `terminalExactRouteRemovalRequested`
- `terminalExactRouteRemovalCompleted`
- `terminalRouteDisposed`
- `terminalRouteRetryScheduled`
- `terminalRouteRetryExhausted`

Ownership rejection records only a controlled category: stale route ownership,
missing route, changed Navigator, navigation failure, or retry exhaustion. Events
reuse the existing hashed call and exact CallKit fingerprints plus lifecycle
generation. No raw invite, CallKit, channel, UID, token, credential, contact, or
payload value is persisted.

## Navigation Instrumentation

`AgoraCallScreen` submits events at the existing terminal-route boundaries without
awaiting the recorder: exit request, covered-route detection, exact removal
request/return, normal pop request, retry scheduling/exhaustion, and widget
disposal. Per-route flags avoid duplicate exit, covered, rejection-category, and
disposal records where possible.

Recorder calls are wrapped so a synchronous diagnostic failure cannot alter
navigation. The recorder already serializes and catches asynchronous storage
failures. No navigation branch, exact-route removal operation, retry delay/limit,
cleanup gate, RTC path, Firestore transition, or native behavior changed.

## Persistence And Timing Proof

`terminal route outcome timeline survives recorder restart` writes the route
timeline through the real filesystem-backed atomic store, constructs a new
recorder, and recovers the ordered stages, lifecycle generation, and stable safe
fingerprints. The persisted JSON is asserted not to contain raw identifiers or
sensitive field names.

`blocked durable storage never delays terminal route disposal` blocks the first
diagnostic write while a manager-owned terminal route closes. The route is still
disposed within the existing 2,000 ms simulated budget; after storage is released,
the ordered exit/pop/disposal timeline persists. This proves navigation does not
await diagnostic I/O.

## Route Outcome Coverage

- Normal current-route navigation persists exit, Navigator pop, and disposal.
- A covered call route persists the covered state and exact route removal
  request/completion without dismissing its covering route.
- A manager-detached terminal route persists safe stale-ownership rejection and
  exact removal completion.
- One controlled final-boundary failure persists retry attempt 1, then successful
  disposal, with no exhaustion event.
- Persistent final-boundary failure persists attempts 1 through 8 and one retry
  exhaustion event while preserving the existing retry limit.
- Stale Call A after Call B ownership persists only A's safe fingerprints; B's
  lifecycle generation and route ownership remain intact and B receives no stale
  A diagnostic identity.

No new functional defect was found. A widget-test-only fake-clock cleanup wait was
resolved by installing the recorder override inside each widget test's clock zone;
production code and navigation timing were unchanged.

## Validation

- Durable diagnostics file: passed, 16 tests.
- Terminal route ownership file: passed, 33 tests.
- Focused diagnostics/recovery/media/lifecycle matrix: passed, 193 tests.
- Complete Call V2 Flutter suite: passed, 2,389 tests.
- iOS RunnerTests: passed, 30 tests on the iOS 26 simulator.
- `flutter analyze`: passed, no issues.
- Format check: passed, 4 files unchanged.
- `git diff --check`: passed.
- Dependency diff: none.

The complete suite's legacy phase-isolation tests require a clean worktree. The
four pre-existing untracked Aider/architecture artifacts were therefore moved
temporarily outside the worktree and restored afterward. Their before/after
SHA-256 manifests are identical.

## Files Changed

Implementation and tests:

- `lib/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart`
- `lib/screens/call/agora_call_screen.dart`
- `test/call_v2/diagnostics/call_v2_durable_boundary_diagnostics_test.dart`
- `test/call_v2/real_flow/call_v2_route_ownership_terminal_transition_test.dart`

Agent-loop metadata:

- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Scope And Limitations

No TestFlight build, backend/Firebase deployment, physical call, dependency
change, native source change, Agora/RTC change, CallKit/PushKit change, Firestore
protocol change, cleanup-gate change, route-removal semantic change, or retry-limit
change occurred.

Deterministic tests prove persisted source-level outcomes and isolation. They do
not establish physical-device behavior or 100% reliability.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review the persistent terminal-route timeline and deterministic ownership coverage
before authorizing a TestFlight build.
