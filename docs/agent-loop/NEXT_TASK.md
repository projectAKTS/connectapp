# Active Task - Android Invite Push Without The APNS Wait (F6)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `345e8c9`

## Review Of Physical Android Verification (Claude, 2026-10-29)

- Accepted: F1 (`613c2f7`, verified on the A55), F4 (`8c1b6f6`, source and a
  RED-checked test).
- F2 (`f7d414c`): the user deployed `onCallInviteUpdated` on 2026-10-29. It
  was then verified 3/3 on emulators (`345e8c9`).

## Problem (F6)

`onCallInviteCreated` sends three pushes in order: the iOS VoIP push, then
the APNS alert check, then the Android FCM.
- When the callee also has a delivered iOS VoIP token, the APNS alert check
  sleeps 4 s (`CALL_ALERT_FALLBACK_DELAY_MS`) before re-reading the invite.
- Android waits behind that sleep: on the Samsung phones the call UI
  appeared 6-7 s after the caller tapped.

## Goal

- Android (non-iOS) FCM tokens get the invite at the start, concurrently
  with the VoIP push.
- iOS FCM tokens stay a last-resort fallback. They get the invite only when
  neither VoIP nor the APNS alert was delivered.
- iOS behaviour is unchanged: the same VoIP push and the same delayed alert
  check.

## Allowed Files

- New `connect_functions/call_invites/invite_fcm_plan.js`: which FCM tokens
  are sent at the start, and which only as the fallback.
- New `connect_functions/test/call_invites/invite_fcm_plan.test.js`.
- `onCallInviteCreated` in `connect_functions/index.js`.
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`.

## Strict Non-Goals

- No client change, no rules change, no TestFlight.
- No deploy by Claude. The user deploys only
  `functions:onCallInviteCreated` (approved per action).
- Do not change `CALL_ALERT_FALLBACK_DELAY_MS` or the iOS alert policy.

## Validation

- `node --test test/call_invites/*.test.js`.
- `npm run test:call-v2:emulator` and `npm run test:call-v2:rules`.
- `node --check index.js`.
- After the user's deploy: emulator calls (A to venus on B) in fg/bg/killed.
  Record the ring time and `serverDiag` (`serverFcmSent`, policy).

## Commit And Handoff

- Implementation: `fix(functions): send the Android call invite before the APNS alert wait`.
- Handoff: `chore(agent-loop): record android invite push review handoff`.
- Push `call-v2`.
