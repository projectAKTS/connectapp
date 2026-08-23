# Review Handoff

Phase: `physical_repeat_call_pending_accept`
Status: `ready_for_review`
Authorized baseline: `6b548b2f4ade470e4b8b02fae9d5517ee0438ec9`
Starting HEAD: `3e5eec1dd50abfb82b81bac556fa42fdc8ab388d`
Implementation commit: `ab9a90e057ae06d6d739355a02e0e6cfade00607`

## Root Cause

The accepted pending invite survived previous-call teardown, but route activation was attempted only once. When CallKit foregrounded the app before its Navigator was mounted, route opening returned navigator unavailable and no event-driven continuation retried the already-accepted call. The app therefore remained on Home even though Call 2 acceptance ownership was still valid.

## Correction

- Added an exact invite- and generation-scoped accepted-route continuation that retains the accepted obligation until route success, authoritative terminal/missing state, generation invalidation, or explicit reset/sign-out.
- Separated completed server acceptance from route retry so Navigator readiness retries never repeat the acceptance transaction.
- Kept lifecycle and accepted intent owned when Navigator is temporarily unavailable or route opening is busy.
- Connected the existing app-resumed lifecycle signal to a bounded Navigator readiness probe: 12 attempts at 250 milliseconds, with no indefinite polling.
- Coalesced native Accept, plugin Accept, teardown completion, and repeated resume events through one single-flight continuation.
- Revalidated the authoritative invite and exact lifecycle generation before every continuation; stale, terminal, and missing work is discarded safely.
- Cleared the continuation only after route success or a controlled invalidation/cleanup condition.
- Added only boolean/counter diagnostics; no invite, user, call, token, channel, device, or payload data is exposed.

## Tests

- Exact physical timing: Call A teardown, Call B CallKit Accept, first route attempt before Navigator mount, resumed continuation, one route, and one RTC owner.
- Immediate-Navigator path remains single-pass.
- Multiple resumed events coalesce into one route attempt.
- Native/plugin/resume duplicates converge without a retry storm.
- Terminal invite while waiting is discarded and cannot later open.
- Invalidated generation cannot open a route.
- Route-busy/in-flight continuation remains single-flight.
- Twenty sequential background accept cycles each produce exactly one route and one RTC owner.

## Validation

- `flutter analyze`: passed, no issues.
- `flutter test test/call_v2 --no-pub`: passed, 2,260 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`: passed, 3 tests.
- Focused rapid lifecycle manager tests: passed, 57 tests.
- Focused notification ownership tests: passed, 15 tests.
- `git diff --check`: passed.

## Safety

No engine-cleanup policy, Agora/RTC/token architecture, native code, Firebase/backend code, rules, or deployment configuration changed. No Firebase service was contacted, no TestFlight build was created, and nothing was deployed.

## Physical Follow-up

Install the pushed branch tip on both iPhones and repeat Call 1 followed by background Call 2 Accept while Call 1 teardown is completing.
