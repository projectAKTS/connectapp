# Active Task - Media-Owned ACK Ordering Revision

Branch: `call-v2`

Starting SHA: `76eca6691d219abbf1a1a7cde411c76332ab02a3`

Implementation under review:
`3e9628d8d224a5f7cb1667874e10211554b4fc23`

## Goal

Correct one ordering defect in physical media join success: once Agora
`onJoinChannelSuccess` has fired and the exact physical media/session
generation is still current, acknowledge exact native media ownership and
transfer the matching accepted-native watch before awaiting Firestore join
progress.

## Required Ordering

1. Receive actual Agora join-success callback.
2. Validate the exact current `CallV2PhysicalMediaKey`, lifecycle generation,
   and accepted CallKit identity.
3. If an exact accepted CallKit identity exists, call
   `acknowledgeNativeMediaOwnership`.
4. Revalidate exact media/session ownership after that await.
5. If acknowledgment succeeded and the exact accepted-native watch still
   matches, transfer that watch to media-owned.
6. Call the existing `reportAgoraJoinSuccess` manager/Firestore progress path.

Firestore progress remains required but must not keep a successfully joined,
exactly owned native call eligible for the no-owner watchdog.

## Failure Semantics

- Never acknowledge before actual Agora join success.
- A stale media key before join success sends no acknowledgment.
- If ownership becomes stale while native acknowledgment is awaiting, its late
  completion cannot transfer a watch or mutate a newer call.
- Do not remove or weaken `reportAgoraJoinSuccess`.
- Do not fabricate route ownership.
- Existing terminal cleanup remains authoritative.

## Required Tests

- Block `reportAgoraJoinSuccess`/Firestore progress deterministically after
  actual join success and prove, while blocked:
  - one exact media-owned acknowledgment has already occurred;
  - the exact accepted-native watch is media-owned/no longer deadline-eligible;
  - no route-owned acknowledgment occurred.
- Release progress and prove normal lifecycle reporting completes without a
  duplicate media acknowledgment.
- A stale media key before join success produces zero acknowledgment.
- If exact ownership changes while native acknowledgment is awaiting, late
  completion cannot transfer or mutate newer Call B.

## Allowed Files

- `lib/services/call_session_manager.dart`
- focused tests under `test/call_v2/**`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/STATE.json`
- this task file

## Strict Non-Goals

Do not change the physical media owner/runtime architecture, screen attachment,
widget detach, video or outgoing-audio route-first behavior, CallKit audio
activation latching, native watchdog duration, route-owned ACK behavior,
accepted transaction architecture, route/redial ownership, PushKit/APNs,
backend, dependencies, or native code.

## Validation

Run the focused race test, background media tests, route ownership, exact
CallKit, notification ownership, rapid lifecycle, repeated lifecycle,
foreground recovery, full `test/call_v2 --no-pub`, iOS RunnerTests,
`flutter analyze`, `git diff --check`, and dependency diff inspection.

Do not build TestFlight, deploy, or claim physical success.
