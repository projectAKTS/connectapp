# Firestore Watch-Stream Churn And Client Wedge Handoff

STATUS: `ready_for_review`

STARTING_SHA: `aedfe11daaa9819124e9ca8c8a108e269bc786f7`
AUTHORIZATION_SHA: `57f7673`
IMPLEMENTATION_SHA: `3db9e00d32e9f4a31cb06377c64e1afcd6ba0ed3`
ENDING_SHA: `SELF`

## Physical Evidence (TestFlight 1.0.2 (202610251434), callee iPhone)

Sources: Firestore invite records (read-only, identifiers hashed), the app
container's durable timeline, and the device unified log for 22:13-22:16 EDT.

- Calls 1 and 2 (02:13:35, 02:13:53 UTC) connected and returned Home.
- Call 3 (02:14:05): native CallKit accept 02:14:08.164; the Flutter accept
  transaction callback entered at 08.286 but `transaction.get` never
  returned; attempts 2 and 3 never entered their callback; every other
  Firestore read timed out (`incoming_recovery_query_error ... timeout`).
  The native 20 s safety watchdog ended CallKit at 02:14:28.192.
- Call 4 (video, 02:14:41): accepted at 44.399, logged
  `pending_accept_recorded ... callLifecycleState: teardown` behind call 3,
  never started; watchdog ended it at 02:15:04.525.
- Unified log: dozens of `[FirebaseFirestore] Listen for query at chats /
  connections failed: Missing or insufficient permissions` and
  `WatchStream ... 'Not found: Target id not found'` per 10 s; at
  02:14:08.493 `WriteStream ... 'Unavailable: Network connectivity changed'`
  and then no Firestore log line at all for the rest of the window. In calls
  1 and 2 the write- and watch-stream close lines appear in the same
  millisecond; in call 3 the watch-stream close never appears.

## Causal Sequence

1. Firebase iOS 11.10.0: on a connectivity change
   `GrpcConnection::RegisterConnectivityMonitor` calls `FinishAndNotify` on
   each active call on Firestore's single serial worker queue;
   `GrpcStream::Shutdown` -> `FastFinishCompletionsBlocking` ->
   `GrpcCompletion::WaitUntilOffQueue()` waits without a timeout. The watch
   stream's completion never left the gRPC queue, so the worker queue blocked
   permanently and every Firestore operation in the process hung. Same
   signature as open upstream issue firebase/firebase-ios-sdk#12522, whose
   reproduction stopped when the churning listener was removed.
2. App-driven precondition: `HomeContentScreen` is a kept-alive Offstage tab
   beneath every call route. `_HomeTopBar` and `_WelcomeCard` created
   `users/{uid}`, `chats` x2 and `connections` x3 `.snapshots()` streams in
   `build()` and nested builders; the screen also created the welcome-card
   user stream, the posts query and one `posts/{id}` stream per cell in
   `build()`. Every rebuild re-created those watch targets.
3. `DiagnosticService` and `_syncNativePushDiagnostics` wrote `users/{uid}`
   on every call/push diagnostic stage, so each call stage rebuilt Home and
   re-created its listeners (the `chats`/`connections` queries are also
   rejected by security rules, adding an error round-trip each time).
4. Consequence: call 3's accept transaction and failure writes hung; its
   lifecycle teardown awaited Firestore forever; call 4 queued behind it.

## Correction

- Home creates every Firestore stream once per identity (user id, post id,
  posts reload key) instead of in `build()`; rendering logic is unchanged.
- Remote `users/{uid}.diag` writes run only with `ENABLE_RUNTIME_DIAG`
  (release default off); local `[DIAG]` logs and the durable on-device
  recorder are unchanged.
- Production-identical seams: Home reads `HelperlyTestRuntime.firestore` /
  `currentUid` / `currentDisplayName` (which resolve to
  `FirebaseFirestore.instance` / `FirebaseAuth.instance.currentUser`).

## RED / GREEN (identical files, baseline `57f7673` + test seams only)

- `test/home/home_firestore_listener_stability_test.dart`
  (`c940a28c...`): RED 0/4 (`chats` 4 vs 2 on first build; 24 vs 14 and 36 vs
  16 after 10 updates; diagnostics wrote `diag`); GREEN 4/4.
- `test/home/home_content_listener_stability_test.dart` (`f65d4d26...`):
  RED (`posts` listener creations 44 vs 14 after 10 updates); GREEN 1/1.

## Validation

- Entire Flutter `test/` folder on a clean checkout of the implementation SHA:
  2,414 passed, 2 failed. Both failures (`test/call_message_stability_test.dart`)
  are the integration-test wrapper requiring `HELPERLY_TEST_MODE`; they fail
  identically on the baseline and are unrelated.
- Complete Call V2 suite included above (2,405 previously; unchanged).
- iOS RunnerTests (iOS 26.0, iPhone 17 Pro simulator): 31 passed.
- `flutter analyze`: no issues. Format: unchanged. `git diff --check`: clean.
- Dependency and lockfile diff: none.

## Remaining Risks

- The SDK's unbounded `WaitUntilOffQueue` remains in Firebase iOS 11.10.0 and
  is not fixed upstream; this change removes the proven app-driven trigger,
  not the SDK defect. If Firestore still wedges, accepted calls cannot
  complete until the app restarts.
- `chats` and `connections` Home queries are rejected by security rules
  (pre-existing backend issue; badges likely never worked). Not changed.
- No physical verification yet.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Controlled TestFlight build of this SHA, then the same consecutive-call test.
