# Active Task — Physical Call 2 Diagnostics and Native Safety Watchdog

Branch: `call-v2`

Starting SHA: `ad2a5149a44bc053ee54ca3bfd93b2327765c36c`

## Goal

Add a safe two-call diagnostic checkpoint ledger and a minimal exact-ID native
CallKit safety watchdog. This revision must expose where physical Call 2 stops
without changing routing, RTC, token, Firestore call protocol, PushKit
presentation, or CallKit presentation ownership.

## Physical Evidence

- Call 1 connects audio/video and ends normally.
- Call 2 receives PushKit, presents one native CallKit UI, and is accepted once.
- Helperly foregrounds but remains on Home; no Flutter call route or Agora join
  occurs.
- The native CallKit session and iOS call/video indicator remain active until
  force quit.

## Authorized Files

Modify only where required under:

- `lib/call_v2/**`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `lib/main.dart` only if needed to expose an existing hidden developer entry
- `ios/Runner/AppDelegate.swift`
- `test/call_v2/**`
- `test/notification_foreground_recovery_test.dart`
- `docs/agent-loop/**`

Do not modify backend/functions, Firestore rules, Firebase configuration,
dependencies, platform entitlements, Agora cleanup/token/App ID behavior, or V1.

## Diagnostic Ledger

Implement an ordered in-process ledger retaining at most the previous and
current call timelines. Each entry contains only a monotonic sequence, elapsed
milliseconds, and a controlled stage enum/name. Summary state may contain only
safe booleans, counters, enums, and blocker codes.

Record controlled native and Flutter checkpoints covering PushKit receipt,
CallKit presentation/accept/bridge, accepted ownership, teardown completion,
resume/Navigator readiness, route attempt/open, RTC setup/join, remote join,
terminal observation, native watchdog timeout, native end request, and native
end verification.

Never retain or expose UIDs, invite/call IDs, channels, CallKit UUIDs, device
identifiers, tokens, payloads, credentials, raw provider data, or stacks.

Expose a hidden developer-only in-app view/copy mechanism for a compact CALL 1,
CALL 2, and SAFE STATE report. It must not make Call V2 publicly reachable or
enable rollout.

## Native Safety Watchdog

- Start one exact-UUID watchdog after native CallKit Accept.
- Coalesce duplicate accepts for the same UUID.
- Flutter sends `callkitRouteOwned` with the exact accepted UUID only after the
  actual Flutter call route has opened successfully and ownership is still
  valid.
- Matching route-owned ACK or native terminal event cancels the watchdog.
- If the 20-second deadline wins, end the exact native call once, perform
  bounded verification, record only safe checkpoints, and clear ownership.
- Ignore late ACK after timeout and late timeout after ACK.
- Route-owned ACK must not be sent for pending Navigator, route busy, accepted
  pending, Firestore accepted/joining state, failed route push, or Agora setup.

## Forbidden Changes

Do not rewrite `CallSessionManager` routing, add another accepted continuation
model, change the engine cleanup coordinator, change Agora/token/backend
behavior, modify Firestore protocol/rules, change PushKit presentation, change
CallKit single-owner policy, deploy, or build TestFlight.

## Required Tests

1. Native Accept starts one watchdog; duplicate exact UUID accepts coalesce.
2. Actual route open sends one exact route-owned ACK and cancels the watchdog.
3. Navigator unavailable sends no ACK.
4. Timeout ends and verifies the exact native call.
5. ACK just before timeout wins; timeout just before ACK wins and late ACK is
   ignored.
6. Native terminal event cancels the watchdog.
7. Sequential calls have independent watchdog ownership.
8. Diagnostic timeline ordering is monotonic, retains two calls, and contains
   no unsafe identifiers or sensitive key wording.
9. Existing Call V2 and foreground recovery suites remain passing.

## Validation

```bash
flutter analyze
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

Run relevant iOS/unit tests if available. Do not deploy or build TestFlight.
