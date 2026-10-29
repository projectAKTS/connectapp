# Android Invite Push Handoff (F6)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `345e8c9`
AUTHORIZATION_SHA: `2223473`
IMPLEMENTATION_SHA: `bb1b254`
ENDING_SHA: `SELF`

## Change

`onCallInviteCreated` used to send in order: the VoIP push, then the APNS
alert check (a 4 s sleep when VoIP was delivered), then the FCM. Android
rang only after all of that.

Now:
- `call_invites/invite_fcm_plan.js` splits the callee's FCM tokens:
  - `immediate`: non-iOS tokens (`fcmForFallback`);
  - `iosFallback`: the rest of `fcmAll`.
- The `immediate` FCM send starts before the VoIP push and runs
  concurrently with it. It is awaited before the function finishes.
- `iosFallback` is sent only when neither VoIP nor the APNS alert was
  delivered. That is the same token set as before, which sent `fcmAll` in
  that case.
- `serverFcmSent`/`serverFcmFailed` now sum both sends. The policy string
  is now `android_fcm_with_voip_then_delayed_alert_fallback`; no client
  reads it.
- iOS is unchanged: the same VoIP push, the same 4 s delayed alert check
  and the same alert.

## Validation

- `invite_fcm_plan.test.js`: RED (module missing), then GREEN 4/4.
- `node --test test/call_invites/*.test.js`: 26/26.
- `npm run test:call-v2:emulator`: 256/256.
- `npm run test:call-v2:rules`: 10/10.
- `node --check index.js`: OK.
- Baseline before the deploy, production functions, emulator B (venus)
  with A (Baris) calling. Time from the caller's tap to B ringing:

  | Mode | Ring |
  |---|---|
  | bg | 6.4 s, 5.6 s |
  | killed | 6.1 s, 5.5 s |

## Pending

- The user deploys only `functions:onCallInviteCreated`.
- Then the same emulator runs are repeated; expected ~4 s faster.
- Not verified on a physical phone yet. The user brings one Android phone
  later today.

PHYSICAL_FIX_CLAIM: none.
