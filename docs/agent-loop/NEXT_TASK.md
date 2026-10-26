# Active Task - HTTPS Call-Invite Signaling (Firestore-Independent Critical Path)

Branch: `call-v2-https-signaling` (the physically verified baseline is locked
as `stable/calls-oct-26` and tag `stable-calls-oct-26`; do not modify them)

Starting SHA: `46a71e94aa17e26478a929ab71b786a9f83312d2`

Authorized by the user on 2026-10-26 after TestFlight 1.0.2 (202610252344)
passed three consecutive audio calls and two video calls.

## Problem

The Firebase iOS SDK (11.10.0) can wedge its single Firestore worker queue
in `GrpcStream::Shutdown` -> `WaitUntilOffQueue()` on a connectivity change
(upstream firebase-ios-sdk#12522, unfixed). The proven app-side trigger was
removed in `3db9e00`, but every call-critical state change (accept, decline,
joining/connected stages, terminal transitions) still runs as a client
Firestore transaction, several of them without any timeout. If the SDK
wedges again, an accepted call cannot connect and an unfinished teardown
blocks the next call.

App Check: the app requests App Attest, but the binary has no App Attest
entitlement and Firebase has no App Attest configuration, so every token
exchange returns 403 (App Check is unenforced, so nothing fails today).
DeviceCheck is fully configured.

## Goal

Make call-invite state transitions independent of the Firestore client by
routing them through one HTTPS callable on the existing `callInvites` model,
keep the current Firestore transactions as a bounded fallback, and fix App
Check token issuance.

## Allowed Files

- `lib/main.dart` (App Check provider only)
- `lib/services/call_session_manager.dart`
- new `lib/services/call_invite_signaling.dart`
- `connect_functions/index.js` (one new callable export)
- new `connect_functions/call_invites/**`
- new/updated tests under `test/**` and `connect_functions/test/call_invites/**`
- `docs/agent-loop/NEXT_TASK.md`, `docs/agent-loop/STATE.json`,
  `docs/agent-loop/HANDOFF.md`

## Required Implementation

1. App Check: activate `AppleProvider.deviceCheck` (debug provider unchanged).
2. Server `callInviteTransition` callable (us-central1, authenticated) with
   actions `accept`, `decline`, `terminal`, `stage`, mirroring the client
   transactions exactly: participant/recipient checks, status preconditions,
   allowlisted fields only, server timestamps, idempotent repeats.
3. Client `CallInviteSignaling`: invoke the callable with a short timeout;
   on any failure (including not-yet-deployed) fall back to the existing
   Firestore transaction, which gains a bounded timeout. Tests default to the
   Firestore path so existing behavior is unchanged unless a test injects a
   signaling fake.
4. Bound every call-state Firestore transaction that currently has no timeout.
5. Regression tests: RED on the baseline, GREEN after; include a scenario in
   which the Firestore transaction never completes yet accept, joining,
   connected, and terminal transitions succeed through signaling, and the
   next call is not blocked.

## Strict Non-Goals

No change to the locked stable branch/tag, PushKit/CallKit native code,
Agora/RTC setup, terminal-route navigation, Firestore security rules, or
dependencies. No backend deployment, Firebase console change, TestFlight
build, or upload without separate user approval.

## Validation

Server unit tests (`node --test`), new Flutter regressions RED/GREEN, the
complete Flutter `test/` folder, iOS RunnerTests, `flutter analyze`,
formatting, dependency/lockfile diff, and `git diff --check`.

## Commit And Handoff

Commit implementation/tests separately from the handoff on
`call-v2-https-signaling`, set `STATE.json` to `ready_for_review`, push that
branch only.
