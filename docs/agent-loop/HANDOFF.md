# Terminal Route Timing Verification Handoff

STATUS: `ready_for_review`

STARTING_SHA: `7ac433472600527515365f3bc179c61a2622be09`
AUTHORIZATION_SHA: `0304ca9`
IMPLEMENTATION_SHA: `37f8a80883ac21c7164811d3f31fb62e63249258`
ENDING_SHA: `SELF`

## Result

The existing source correction in `clearStaleUiFlags()` required no further
production change. New widget coverage proves that an exact manager-owned
receiving audio route reaches Home within a strict 2,000 ms simulated-time
budget after remote terminal observation and stale-native reconciliation.

The new tests pump in 16 ms frames and assert complete route disposal. They do
not use the existing 40-second clock jump as evidence of prompt navigation.
The production-path test also waits for the real manager-owned route future to
complete, observes `route_pop` and `reset_session_state_done`, and verifies
that late terminal/reconciliation callbacks cannot reopen the route.

## Baseline Evidence

The original baseline-red/fixed-green regression remains unchanged:

`remote terminal route returns home after native stale UI reconciliation`

On the uncorrected baseline it reached `route_pop_stale_owner_blocked`, left
`Call ended` visible, and failed to show Home after more than 40 simulated
seconds. It passes with the accepted `clearStaleUiFlags()` ownership fix. The
new timing tests provide separate prompt-navigation proof.

## Production-Path Proof

Primary test:

`production manager-owned receiver route returns Home within two seconds after stale native reconciliation`

This test uses:

- the actual accepted CallKit recovery and authoritative transaction path;
- the real `CallSessionManager._openCallScreen()` production
  `Navigator.push()` path;
- a real `MaterialApp`, Navigator, `AgoraCallScreen`, and `PopScope`;
- one shared physical-audio media runtime and one RTC join owner;
- remote terminal handling and the exact manager reconciliation operation;
- exact CallKit cleanup and the real route-future completion/reset path.

It proves the `AgoraCallScreen` and managed-route scope disappear, Home is
visible, the manager returns idle, native calls are absent, physical media is
cleaned, and the route and RTC owner counters remain exactly one.

Companion tests:

- `manager-owned receiver route returns Home within two seconds after immediate stale native reconciliation`
- `stale native reconciliation during auto-close keeps exact owner until prompt route disposal`

The second companion uses the existing final-pop test barrier to place
reconciliation at the final navigation boundary. Exact ownership remains with
the terminal route until its authorized pop completes.

## Notification Reconciliation Coverage

`NotificationService._resetStaleIncomingUiIfNeeded()` is private, guarded by
`Platform.isIOS`, and calls the static plugin API
`FlutterCallkitIncoming.activeCalls()`. A portable host widget test cannot
invoke that private iOS-only entry without changing production design.

Source inspection confirms its reconciliation call is
`CallSessionManager.instance.clearStaleUiFlags()`. The widget tests invoke
that exact public manager boundary immediately before auto-close and while
auto-close is paused at its final pop boundary. This is explicit call-site
coverage, not a claim that the private platform entry itself ran in the host
test.

## Isolation And Cleanup Proof

- Existing stale-A/new-B ownership tests remain green; a stale route cannot
  clear or dismiss the newer exact route owner.
- Reconciliation during final pop does not revoke the exact terminal owner.
- The production-path test starts one media runtime, joins once, then confirms
  physical-media cleanup and no remaining owner.
- Exact CallKit cleanup removes the matching native call only.
- Cleanup emits `cleanup_gate_released` with the next-engine gate available
  before the session reaches reusable idle.
- Late remote-terminal and reconciliation callbacks do not recreate the
  disposed route or media runtime.

## Files Changed

Implementation/test commit:

- `test/call_v2/real_flow/call_v2_background_audio_media_integration_test.dart`
- `test/call_v2/real_flow/call_v2_route_ownership_terminal_transition_test.dart`

Agent-loop metadata:

- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

No production file or dependency file changed. The pre-existing untracked
architecture document and Aider artifacts remain untouched.

## Validation

- New strict timing regressions: passed, 3 tests.
- Maximum asserted simulated latency: 2,000 ms, pumped in 16 ms frames.
- Focused ownership/recovery/media/lifecycle matrix: passed, 218 tests.
- Full Call V2 suite: passed, 2,377 tests.
- `flutter analyze`: passed, no issues.
- Format check: passed.
- `git diff --check`: passed.
- Dependency diff: none.

Legacy repository-isolation tests enumerate untracked files. For the full
suite only, the four pre-existing untracked artifacts were moved outside the
worktree and then restored byte-for-byte to their original paths. Their
untracked status remains unchanged.

## Scope And Limitations

No production code, route behavior, CallKit connected timing, cleanup policy,
Agora/RTC implementation, Firebase/backend, Firestore protocol, PushKit/APNs,
native code, timeout, dependency, or build configuration changed. No
TestFlight build, deployment, backend contact, or physical call occurred.

The 2,000 ms result is deterministic simulated widget time. It proves the
source navigation path and ownership ordering under the modeled conditions;
it does not establish measured device latency or 100% physical correctness.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review the deterministic timing evidence before deciding whether to authorize
another physical TestFlight validation.
