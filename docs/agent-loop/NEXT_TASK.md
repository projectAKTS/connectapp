# Active Task - Accepted Call Exact-Identity Correction

Branch: `call-v2`

Starting SHA: `71fd2070cd60affe15019b8db0730e36f1a4015c`

## Physical Evidence

Call 1 routes and joins normally, including a duplicate exact native Accept.
Call 2 reaches `acceptedRecoveryEntered` but is incorrectly reported as
`acceptedRecoveryCoalescedSameCall`; it never records accepted ownership or
attempts a route. Call 2 uses a different exact CallKit UUID while the invite
identifier can equal Call 1's fixture value.

## Goal

Make NotificationService use the same canonical accepted-call identity rule as
CallSessionManager: when both exact CallKit IDs are present, equality is
authoritative and an exact-ID mismatch is distinct. Use invite identity only
when at least one exact ID is unavailable. Prove terminal retry ownership does
not continue after the exact native call terminalizes.

## Allowed Files

- `lib/services/notification_service.dart`
- narrowly relevant accepted-recovery tests under `test/call_v2/**`
- `docs/agent-loop/**`

Modify another Call V2 identity site only if it violates the same canonical
rule. Do not change RTC, PushKit, AppDelegate, native watchdog, routing,
Navigator, Firebase/backend, Firestore schema/rules, or dependencies.

## Required Regression Proof

- Same invite plus different non-empty exact IDs is distinct.
- Same invite plus equal exact IDs coalesces idempotently.
- Matching invite fallback works when at least one exact ID is absent.
- Routed/duplicated/terminated A cannot coalesce B when B has the same invite
  value and a different exact ID.
- Terminal B releases retry ownership and later retry callbacks cannot mutate
  recovery state.

## Validation

```bash
flutter analyze
flutter test test/call_v2/real_flow/call_v2_notification_ownership_test.dart --no-pub
flutter test test/call_v2/real_flow/call_v2_rapid_call_lifecycle_manager_test.dart --no-pub
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

Do not deploy or build TestFlight. Do not claim physical success.
