# Active Task - Native Firestore Must Not Start Before FlutterFire (F9)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `ec46d49`. The F8b iOS code is uncommitted in the working tree
and gets committed with its own message first.

## Problem (F9) - iOS crash on answering from a call notification

User's iPhone 16 Pro Max (iOS 26.6.2), cable-installed build 135. With the
app killed and the phone locked, the user tapped the incoming-call
notification. The app opened, crashed, and the user landed on the home
screen. The call was never accepted; the caller timed out after 51 s.

Two crash reports (23:56:34 and 23:59:29) are identical. Each is about 1 s
after process launch, `SIGABRT`:
`-[FIRFirestore setSettings:]` <- `-[FLTFirebaseFirestorePlugin
getFIRFirestoreFromAppNameFromPigeon:]` <- `enableNetworkApp`, i.e. Dart's
first Firestore call (`FirestoreReadHelper` `enableNetwork`).

Cause:
- The notification response handler (`AppDelegate`, the
  `incoming_fallback_accept_received` path) calls `syncInviteStatus` before
  Dart runs. It uses `Firestore.firestore()`, which starts the native
  instance.
- FlutterFire then misses its cache, calls `setSettings` on the started
  instance, and Firestore throws an illegal-state error.
- The same applies to the fallback decline and to every `syncInviteStatus`
  caller while Dart has not touched Firestore yet.
- This has been in place since 255269c (2026-08-05). A TestFlight-build
  `SIGABRT` on 2026-10-30 is unsymbolicated but is likely the same crash.

## Goal

Native code obtains Firestore only through FlutterFire's cache:
1. Reuse the cached instance (`FLTFirebaseFirestoreUtils
   getFirestoreInstanceByName:databaseURL:`).
2. If there is none, create it as FlutterFire would: default settings plus
   `dispatchQueue = FLTFirebaseFirestoreReader getFirestoreQueue`. Then
   register it with `setCachedFIRFirestoreInstance:forAppName:databaseURL:`,
   with the app name and `(default)`.
3. If those classes or selectors are missing, skip the native write, because
   Dart's accept/decline recovery owns it. Never start Firestore natively
   outside the cache.

## Allowed Files

- `ios/Runner/AppDelegate.swift` (`syncInviteStatus` and a helper)
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`

## Validation

- iOS release builds, and Dart analyze and tests are unchanged.
- Physical iPhone:
  - with the app killed and the phone locked, answering from the
    notification and from CallKit connects without a crash;
  - no new `Runner-*.ips` appears;
  - the foreground and background answers still work.

## Commit And Handoff

- `fix(ios): never start Firestore natively before FlutterFire`.
- Handoff: `chore(agent-loop): record native firestore crash review handoff`.
- Push `call-v2`.
