# Active Task - Physical Android Call Verification

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `341cf94`

Authorized by the user on 2026-10-29:
- "2 tane android telefon taktim test et lutfen ... emulator de test
  edemeyecegimiz herseyi test edebilirsin": physical calls between the two
  connected Samsung phones and the emulators are approved for this task.
- The phones are only available until 2026-10-30. Evidence first; fixes
  found here become the next task unless they are small and can be
  verified on the phones the same day.

## Review Of Step 4 (Claude, 2026-10-29)

- Step 4 (`3ae2314`, `c65e9ab`, handoff `341cf94`): accepted.
  - The notification-permission fix is a real fresh-install bug, found by
    the clean install and covered by a RED-checked test.
  - Killed-app answer latency (~20 s on a loaded host) stays open and is
    measured on real hardware here.

## Problem

Every call so far ran on emulators. Emulators cannot show:
- OEM (Samsung One UI) battery management: sleeping apps, app standby,
  Doze on real hardware, swipe-from-recents behaviour.
- Answering over a real lock screen, with the screen off.
- Real microphone, speaker, earpiece, proximity sensor and camera.
- Real network changes (Wi-Fi to mobile data, airplane mode) during a call.
- Cold start, permission prompts and answer latency on real hardware.
- Behaviour after a reboot without opening the app.

## Goal

A recorded verdict for each scenario below on two physical Samsung phones
running the release APK `com.yakup.helperly` from `c65e9ab`.

## Accounts And Devices

- Baris is only ever the **caller**. Calls to Baris would ring Baris's
  physical iPhone, which must not be called.
- Venus is the callee. Venus may be logged in on both phones and on
  emulators B/C for multi-device runs; unused venus emulators are stopped
  so they do not ring.
- Logins come from `test_artifacts/secrets/test_logins.txt`. Never print
  or commit them.

## Scenarios

1. Fresh install: notification prompt, then first call mic/camera prompts.
2. Single device (phone as venus, caller emulator A or the other phone):
   foreground, background, killed (swipe from recents), screen off and
   locked × answer / decline / caller cancel / ring timeout.
3. Real audio and video between the two phones (the user listens), speaker
   and earpiece, mute, camera switch.
4. Multi-device: both phones as venus; answer on one, the other must stop
   ringing within 15 s; decline on one.
5. Power: `deviceidle force-idle`, app standby bucket `rare`/`restricted`,
   long screen-off idle, battery saver.
6. Network: Wi-Fi off/on and airplane mode during a call; call while the
   callee is offline and comes back.
7. Reboot without opening the app, then an incoming call.
8. Killed-app answer latency on real hardware.

## Allowed Files

- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`.
- Local, git-excluded `test_artifacts/**`.
- No product code. If a defect is found, record it with evidence; a fix
  needs an amendment here first.

## Strict Non-Goals

- No deploy, no TestFlight, no Play upload, no Firebase or rules changes.
- Do not call Baris's iPhone or any user other than venus.
- Do not change production data beyond what normal calls write.

## Validation

- A result table per scenario with timestamps and the relevant
  `pushDiag` / logcat evidence.
- `PHYSICAL_FIX_CLAIM` changes only for scenarios that actually passed on
  the phones.

## Commit And Handoff

- No implementation commit unless amended.
- Handoff commit:
  `chore(agent-loop): record physical android verification review handoff`.
- Push `call-v2`.
