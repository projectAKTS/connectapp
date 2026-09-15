# Review Handoff

Phase: `accepted_call_identity_provenance`
Status: `ready_for_review`
Starting SHA: `f7cd84b84cae820e44d0ed6dcbb25a121b525224`
Implementation commit: `a979ea65aff816cf4d36d6b6a625d94753b332a4`
Ending SHA: `SELF`

## Root Cause

Native incoming CallKit identity reuse was authorized by persisted presentation
state. A stale UserDefaults presentation record from a previous physical call
could make a fresh incoming presentation reuse the old exact UUID. Dart then saw
the new accept as the same physical accepted call and coalesced it before
accepted ownership, route opening, or RTC setup.

Old UUID reuse rule:
An incoming presentation could reuse an existing exact UUID when the prior
identifier was active or when persisted state was `presenting`, `presented`,
`accepted`, or `active`.

New UUID reuse rule:
Incoming reuse is process-local only. A duplicate callback for the same
still-live/in-flight presentation reuses the process-local exact UUID. A new
incoming physical presentation gets a fresh exact UUID even if persisted
terminal-correlation storage still has an older UUID for the same logical call
shape.

## Fix

- Added process-local live presentation ownership in
  `CallV2NativeCallkitIdentityAllocator`.
- Split incoming identity allocation from terminal correlation:
  incoming allocation ignores stale persisted exact IDs, while terminal lookup
  can still use persisted exact IDs for late cleanup.
- Released process-local live identity when the exact CallKit presentation is
  marked terminal.
- Kept accepted bridge forwarding and terminal cleanup tied to the actual exact
  native UUID, not a reconstructed or invite-derived fallback.
- Updated Dart source audits and accepted-recovery regression coverage so
  same-invite/fresh-UUID physical calls do not coalesce as duplicates.

## Invariants

Native UUID invariant:
A new physical incoming presentation receives a fresh exact CallKit UUID after
the previous presentation is no longer live. Duplicate handling for the same
still-live native presentation reuses the exact UUID and does not create a
second native call.

Terminal correlation invariant:
Persisted exact UUID storage is still valid for terminal cleanup correlation,
but it cannot authorize UUID reuse for a new incoming presentation.

Accepted identity invariant:
Two non-empty exact CallKit UUIDs are authoritative. Equal exact IDs are the same
physical accepted call; different exact IDs are distinct even if invite identity
matches. Invite fallback remains only for missing exact-ID compatibility.

## Regression Tests

- `testNativeIdentityIgnoresStalePersistedAcceptedState`: stale persisted
  accepted UUID is not reused for a new incoming presentation.
- `testNativeIdentityIgnoresStalePersistedPresentedState`: stale persisted
  presented UUID is not reused for a new incoming presentation.
- `testNativeIdentityReusesSameProcessPresentationBeforeCxActive`: duplicate
  callbacks for the same in-process presentation reuse one UUID before CallKit
  active state.
- `testNativeIdentityReusesSameProcessActivePresentation`: duplicate callbacks
  for the same active in-process presentation reuse one UUID.
- `testNativeIdentityReleaseAllowsFreshSequentialPresentation`: terminal release
  lets the next same-logical incoming call allocate a fresh UUID.
- `testNativeIdentityProcessRestartAllocatesFreshPresentation`: process restart
  does not reuse persisted UUID for a new incoming presentation.
- `testNativeIdentityKeepsTerminalCorrelationSeparateFromIncomingReuse`: late
  terminal cleanup can use persisted A while a later incoming presentation gets
  fresh B.
- `testNativeExactEndVerificationClearsLivePresentationOwnership`: exact native
  end verification clears process-local ownership.
- `same invite with different exact CallKit IDs is not coalesced`: Dart
  accepted recovery records ownership instead of `acceptedRecoveryCoalescedSameCall`
  for same invite plus fresh UUID B.
- `native source coordinates APNS fallback and PushKit presentation`: source
  audit proves process-local live identity, terminal release, terminal
  correlation, and actual bridge UUID forwarding are present.

## Validation

- `flutter analyze`: passed, no issues.
- Focused NotificationService accepted ownership:
  `flutter test test/call_v2/real_flow/call_v2_notification_ownership_test.dart --no-pub --reporter expanded`
  passed, 38 tests.
- Focused CallSessionManager lifecycle/identity:
  `flutter test test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart --no-pub --reporter expanded`
  passed, 57 tests.
- Full Call V2:
  `flutter test test/call_v2 --no-pub --reporter expanded`
  passed, 2,291 tests.
- Foreground recovery:
  `flutter test test/notification_foreground_recovery_test.dart --no-pub --reporter expanded`
  passed, 3 tests.
- iOS RunnerTests:
  `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'`
  passed, 15 tests.
- `git diff --check`: passed.
- Flutter tooling transiently rewrote `pubspec.lock`; it was restored. No
  dependency files remain changed.

## Files Changed

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`
- `test/call_v2/real_flow/call_v2_notification_ownership_test.dart`
- `test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart`

## Scope Check

No changes were made to Agora RTC/token/App ID architecture, engine cleanup,
Navigator architecture, Firebase/backend/functions, Firestore schema/rules,
dependency versions, rollout settings, or deployment settings. The native
watchdog timeout was not increased. No TestFlight build was created. This
handoff does not claim the physical issue is fixed.
