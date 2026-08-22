# Active Task — Repeat Call Pending CallKit Accept Durability

Branch: `call-v2`

Starting SHA: `6b548b2f4ade470e4b8b02fae9d5517ee0438ec9`

## Goal

Fix the physical repeat-call race where Call B is accepted in native CallKit
while Call A is still ending or tearing down, but Call B's accepted intent is
lost before its route can open.

This task authorizes only the pending-accept lifecycle correction required for
that physical Call 2 failure. Do not reopen Phase 3C presenter work.

## Physical Evidence

- Call 1 connected, worked, and ended normally.
- Call 2 received PushKit and presented one native CallKit UI.
- Native CallKit Accept opened Helperly.
- The Call 2 route did not open and RTC did not start.
- The failure boundary is accepted recovery / pending lifecycle handoff to route
  opening, not Agora media setup.

## Authorized Root Cause

When the previous call lifecycle is `ending`, `teardown`, or `reserving`, a new
incoming invite may be stored in `CallV2CallLifecycleArbiter` as
`_pendingInviteId`.

If native CallKit Accept arrives for that exact pending invite,
`_handleIncomingCandidate(autoAccept: true)` may see `reserveIncoming()` return
duplicate or pending. The existing duplicate auto-accept path depends on both:

- `_incomingPromptInviteId` matching the invite; and
- `_incomingUiOwner` being CallKit.

A merely pending invite does not yet have that presentation-owner state, so the
accepted intent can be returned as ignored or failed. When previous teardown
completes, `_continueClaimedPendingIncoming` then applies normal unaccepted
incoming presentation semantics and requires `ringing`, losing the fact that
CallKit Accept already occurred.

## Authorized Files

Modify only where required under:

- `lib/call_v2/real_flow/**`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/**`

`ios/Runner/AppDelegate.swift` may be changed only if strictly necessary for
safe diagnostics or compatibility with the existing accept payload. Do not
change it if `callkitAcceptedNative` already carries sufficient information.

## Authorized Implementation

1. Add exact invite- and generation-scoped pending accepted intent.
2. When native CallKit Accept targets the pending invite, record durable accepted
   intent instead of returning ignored or failed.
3. Converge plugin Accept duplicates on the same accepted intent in either event
   order.
4. Preserve accepted recovery payload/state while previous teardown remains in
   progress without classifying the wait as a network failure.
5. Make previous teardown completion claim the pending invite and, when its exact
   accepted intent is present, continue directly through the existing guarded
   `_acceptInviteAndOpen` path.
6. Do not resolve or present incoming UI again for an already-accepted pending
   invite, and do not require another user action.
7. Treat `ringing`, `accepted`, and `joining` as valid continuation states for an
   already-accepted pending invite, using existing idempotent acceptance logic.
8. Treat missing, declined, missed, cancelled, ended, and failed pending invites
   as non-openable; clear their accepted intent and close native state safely.
9. Prevent a superseded pending invite's accepted intent from transferring to or
   opening its replacement.
10. Drive continuation from teardown completion rather than retry-timer
    exhaustion.
11. Preserve exactly one route open and exactly one RTC setup owner.
12. Clear pending accepted intent on successful route open, terminal or missing
    invite, supersession, sign out, production hard reset, and explicit
    decline/end before claim. Do not clear it merely because navigation is
    temporarily unavailable, teardown is active, or duplicate recovery arrives.

## Generation Safety

Accepted pending ownership must bind to the exact invite and lifecycle
generation. A late callback from the previous generation must not clear, open,
or mutate the newly claimed call. Claiming the pending invite into the next
generation must transfer only that invite's accepted intent, and consumption
must be atomic/idempotent for that ownership.

## Accepted Recovery Semantics

The same invite waiting behind previous teardown is a durable pending accepted
state, not `AcceptedCallRecoveryResult.failed` and not `pendingNetwork`. It must
not create a retry storm or exhaust retries while teardown is active. Teardown
completion itself must trigger continuation.

## Files and Behavior That Must Not Change

Do not modify:

- `lib/call_v2/real_flow/call_v2_engine_cleanup_coordinator.dart`
- Agora RTC initialization or token architecture
- Agora App ID or token callable
- Firebase backend/functions or Firestore rules
- PushKit presentation policy
- CallKit single-owner policy
- Flutter `IncomingCallScreen` policy

Do not restore dual Flutter Accept/Decline UI. Do not deploy backend changes or
build TestFlight.

## Required Tests

1. Call A connected, teardown begins, B becomes pending, native Accept B arrives,
   A teardown completes, and B automatically opens exactly once with one RTC
   setup owner and no second interaction.
2. Native Accept B arrives before the Firestore pending callback; signals
   converge and B opens once after teardown.
3. Firestore B becomes pending before native Accept; B opens once after teardown.
4. Native and plugin Accept duplicates in both orders produce one accepted
   intent, one route, one RTC owner, and no retry storm.
5. B becomes `accepted` before claim and still opens after teardown.
6. B becomes `joining` before claim and still opens when valid under the current
   state machine.
7. B becomes terminal before claim; no route opens, accepted intent clears,
   native state closes, and lifecycle settles idle.
8. B is superseded by C; B cannot open later and its accepted intent does not
   transfer to C.
9. Repeat 20 sequential cycles: Call N ends, N+1 arrives during teardown, native
   Accept occurs, teardown completes, and N+1 opens once with one RTC owner.

Tests must not use force-quit semantics.

## Safe Diagnostics

Diagnostics may expose only safe state such as:

- `pendingIncomingPresent`
- `pendingAcceptedIntent`
- `pendingAcceptedRecorded`
- `pendingAcceptedClaimed`
- `pendingAcceptedContinuationStarted`
- `pendingAcceptedContinuationCompleted`
- `previousTeardownCompleted`
- `callLifecycleState`
- `routeOpenCount`
- `rtcSetupOwnerCount`
- `sessionIdle`
- `blockerCode`

Do not expose UIDs, invite IDs, channels, CallKit UUIDs, tokens, payloads, Agora
credentials, or raw identifiers.

## Validation

Run and pass after implementation:

```bash
flutter analyze
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

No backend deployment and no TestFlight build.

## Path-Drift Baseline

The authorized path-drift baseline is
`6b548b2f4ade470e4b8b02fae9d5517ee0438ec9`. Legitimate history before this
accepted physical-test checkpoint must not be classified as unauthorized drift.
