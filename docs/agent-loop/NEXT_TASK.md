# Active Task - Answered Elsewhere (Multi-Device Callee)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `d7f208b`

Authorized by the user on 2026-10-27:
- The sequence: build repair, Android incoming call, then this task.
- "Şimdi başla": start before the step-2 review. The step-2 handoff
  (`d7f208b`, `11d46e0`) is still unreviewed; review both together.
- A third emulator is approved for E2E.

## Problem

The same account signed in on two devices behaves badly when one device
answers a call. Verified in source; observed with Baris's iPhone and an
emulator.

1. Accept does not record which device accepted. `planAccept` writes only
   `status: accepted`. A second device of the same callee that taps Accept
   gets `alreadyAccepted` and joins the same call.
2. Nothing tells the other devices.
   - `onCallInviteUpdated` pushes only terminal statuses.
   - `_handleIncomingInviteSnapshot` returns without action for a non-ringing
     status that is not terminal.
   - So the other device keeps ringing and keeps its lifecycle reservation.
     The next call was busy-declined (`busy_active_call`) on the iPhone.
3. Dangerous: when the other device's native UI ends, `actionCallEnded`
   leads to `handleSystemEndedInvite`. With no local session, that writes
   `status: ended` for `accepted`/`joining`/`connected`, which ends the live
   call on the answering device. The server cannot tell the callee's devices
   apart (same uid).

## Goal

When one of the callee's devices answers, the callee's other devices stop
ringing within a few seconds.
- No write, no join, no busy state.
- The answered call is never ended or disturbed by them.
- The next call rings normally on every device.

Old app versions keep today's behavior and are never fenced.

## Allowed Files

- `connect_functions/call_invites/call_invite_transition.js` and its tests
- new `connect_functions/call_invites/answered_elsewhere.js` and tests
- `connect_functions/index.js`:
  - `onCallInviteUpdated`: the accepted branch only
  - export of the token merger for the new helper
- `lib/services/call_session_manager.dart`:
  - send `installationId` with accept/terminal/stage
  - `acceptedElsewhere` decision
  - the Firestore fallback accept
  - local answered-elsewhere dismissal
  - guards on the system end/timeout write paths
- `lib/services/notification_service.dart`:
  - delegate the installation id to the new helper
  - route `call_end` + `answered_elsewhere`
  - give the manager the installation id
- new `lib/services/push_installation_id.dart`, used by the background
  isolate and NotificationService
- `lib/services/android_incoming_call.dart` and `lib/main.dart` (background
  handler): skip `answered_elsewhere` addressed to the answering installation
- `ios/Runner/AppDelegate.swift`, the terminal PushKit branch only. Ignore
  `answered_elsewhere` when this device holds the accepted CallKit call.
- tests under `test/android/**`, new `test/multi_device/**`,
  `connect_functions/test/call_invites/**`
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`

## Required Implementation

### Server

1. `accept` takes an optional `installationId` (`^[A-Za-z0-9_-]{8,80}$`;
   an invalid value is treated as absent).
   - For `ringing`, also write `acceptedInstallationId`.
   - For a progress status with a stored `acceptedInstallationId` that
     differs from the request's: return the new decision
     `acceptedElsewhere`, with no write.
   - Absent on either side: today's behavior (`alreadyAccepted`).
2. `terminal` and `stage` from the callee, with both ids present and
   different: `writeApplied:false` / `applied:false`,
   `reason: answered_elsewhere`.
   - `decline` already applies only to `ringing`.
3. `onCallInviteUpdated`, `ringing` -> `accepted` with
   `acceptedInstallationId`: send `call_end`, `status: answered_elsewhere`,
   and `acceptedInstallationId` to the callee's tokens.
   - Remove every token value found in the answering installation's
     document (fcm/apns/voip) from the merged sets, including legacy
     user-doc tokens.
   - Use VoIP for iOS (the existing terminal path) and FCM data for the rest.
   - Without `acceptedInstallationId`, send nothing.
   - Terminal pushes are unchanged.

### Client

4. One installation id helper, shared by NotificationService (unchanged
   storage file `helperly_push_installation_id`) and the background isolate.
   CallSessionManager receives it through its existing configure/injection
   style.
5. Accept, terminal and stage requests carry `installationId`.
   - The Firestore fallback accept writes `acceptedInstallationId` on
     `ringing` and returns `acceptedElsewhere` on a differing stored id.
   - `acceptedElsewhere` never falls back and never joins.
6. Local answered-elsewhere dismissal: one path, idempotent per invite.
   - Mark the invite answered-elsewhere and handled first.
   - Then clear the incoming prompt, release the lifecycle reservation and
     the pending accepted intent, and end the native UI.
   - Make no Firestore or HTTPS write.
   - Triggers:
     - a snapshot with status `accepted`/`joining`/`connected` and a
       differing `acceptedInstallationId`, while this device has no local
       accept for the invite;
     - the push `call_end` + `answered_elsewhere` for another installation;
     - the decision `acceptedElsewhere`.
7. Guards: `handleSystemEndedInvite`, `handleSystemTimeoutInvite`, and
   decline do nothing for an invite marked answered-elsewhere.
   - The no-session `ended` write is skipped inside its transaction when
     the stored `acceptedInstallationId` differs from this device's.
   - A single-device CallKit end before the session exists still ends the
     call, as today.
8. Android background handler and `AndroidIncomingCall.decide`:
   - `answered_elsewhere` for the own installation is ignored.
   - Otherwise it ends that CallKit id.
9. iOS native: in the terminal PushKit branch, `status ==
   answered_elsewhere` for a CallKit id this device has accepted
   (`callV2NativeAcceptedCallActive` / stored accepted call) is ignored.
   Every other terminal push is unchanged.

## Strict Non-Goals

- No change to the ringing/terminal state machine for single-device calls,
  to rules, to dependency versions, or to the package id.
- No deploy by Claude.
  - The user deploys `callInviteTransition` and `onCallInviteUpdated` after
    review.
  - Server first: it is backward compatible.
- No TestFlight or store upload without the user's separate approval.

## Validation

- Server unit tests:
  - accept with and without ids, `acceptedElsewhere`
  - terminal/stage fencing
  - old-client compatibility
  - recipient token exclusion, including legacy tokens
- Dart unit tests:
  - dismissal on snapshot, push and decision
  - no write from end/timeout after an accept elsewhere
  - the next invite is not busy
  - the Android decide skip
- The full Flutter `test/` folder (pre-existing failures noted).
  `flutter analyze`. Server `node --test` on Node 22.
- Emulator E2E (3 emulators: caller Baris, callee venus on two):
  - accept on one -> the other stops ringing, and the call stays connected;
  - a second call rings on both;
  - single-device regression;
  - background and killed variants on the other device.
- iOS: unit/source evidence only until a TestFlight build is approved.
- `git diff --check`.

## Commit And Handoff

- Implementation commit:
  `feat(calls): answered-elsewhere handling for multi-device callees`.
- Handoff commit:
  `chore(agent-loop): record answered elsewhere review handoff`.
- Push `call-v2`.
