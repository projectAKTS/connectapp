# Active Revision - Firestore Watch-Stream Churn And Client Wedge

Branch: `call-v2`

Starting SHA: `aedfe11daaa9819124e9ca8c8a108e269bc786f7`

Authorized by the user on 2026-10-25 after physical TestFlight build
`1.0.2 (202610251434)` failed on the third consecutive call.

## Proven Physical Failure (callee iPhone, 2026-10-26 UTC)

- Calls 1 and 2 connected and closed correctly.
- Call 3: native CallKit accept at 02:14:08.164; the Flutter accept transaction
  callback started (08.286) but `transaction.get` never returned; attempts 2
  and 3 never entered their callback; every other Firestore read timed out.
  The native 20 s safety watchdog ended CallKit at 02:14:28.192.
- Call 4 (video): accepted, recorded `pending_accept_recorded` behind call 3's
  lifecycle `teardown`, and never started; watchdog ended it at 02:15:04.525.
- Device unified log: Firestore logged dozens of `Listen for query at chats /
  connections failed: Missing or insufficient permissions` and `WatchStream
  Stream error: 'Not found: Target id not found'` per 10 s, then
  `WriteStream ... 'Unavailable: Network connectivity changed'` at
  02:14:08.493 and nothing at all afterwards: the watch-stream close never
  logged.
- Firebase iOS SDK 11.10.0 source: a connectivity change runs
  `GrpcStream::Shutdown` -> `FastFinishCompletionsBlocking` ->
  `GrpcCompletion::WaitUntilOffQueue()` with no timeout on Firestore's single
  serial worker queue. A watch-stream completion that never leaves the gRPC
  queue blocks every Firestore operation for the process lifetime (same
  signature as open upstream issue firebase/firebase-ios-sdk#12522, whose
  reproduction stops when the churning listener is removed).

## Root Cause In App Code

`HomeContentScreen` is kept mounted (Offstage tab, keep-alive). `_HomeTopBar`
and `_WelcomeCard` create `users/{uid}`, `chats` (2) and `connections` (3)
`.snapshots()` streams inside `build()` and nested builders, so every
`users/{uid}` change tears down and re-creates up to five watch targets.
`DiagnosticService` and `_syncNativePushDiagnostics` write `users/{uid}` on
every call/push diagnostic event, driving that churn hardest exactly during
call setup and teardown.

## Allowed Files

- `lib/screens/home/home_content_screen.dart`
- `lib/services/diagnostic_service.dart`
- `lib/services/notification_service.dart` (diagnostic write gating only)
- directly relevant tests under `test/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Implementation

- Create the Home top-bar and welcome-card Firestore streams once per user id
  (and only re-create them when the user id changes), never inside `build()`.
- Write remote `users/{uid}.diag` fields only when `ENABLE_RUNTIME_DIAG` is set;
  keep local `[DIAG]` logging and the on-device durable recorder unchanged.
- Regression coverage proving repeated `users/{uid}` updates and parent
  rebuilds create no additional Home Firestore listeners, and that release
  diagnostics never write the user document.

## Strict Non-Goals

No Firebase SDK upgrade, no security-rule or backend change, no call-flow,
CallKit, PushKit, Agora, or navigation change, no dependency or lockfile change.
No TestFlight build or upload without separate approval.

## Validation

New regression tests RED on the unchanged baseline and GREEN after the fix,
complete Call V2 suite, affected widget tests, iOS RunnerTests, `flutter
analyze`, formatting, dependency/lockfile diff, and `git diff --check`.

## Commit And Handoff

Commit implementation/tests separately from the handoff. Replace `HANDOFF.md`,
set `STATE.json` to `ready_for_review`, commit metadata, push `origin/call-v2`.
