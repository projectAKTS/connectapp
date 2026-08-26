# Review Handoff

Phase: `physical_repeat_call_pending_accept`
Status: `ready_for_review`
Authorized baseline: `6b548b2f4ade470e4b8b02fae9d5517ee0438ec9`
Starting HEAD: `0f79c2d5e317ce82085702b10087531c22a32227`
Implementation commit: `89a9a794bc3459b141f5c849507ca7f1b3990f8a`

## Source Review Gap

The foreground readiness probe stopped immediately when it observed `pendingTeardown`. If app resume occurred before previous-call teardown claimed the accepted pending invite, the probe could end before the accepted-route continuation existed. A later one-shot route attempt could then encounter an unavailable Navigator with no remaining lifecycle event to retry it.

## Correction

- Added a safe manager ownership predicate covering either pending accepted intent or accepted-route continuation.
- Kept the existing NotificationService single-flight readiness owner alive across both `pendingTeardown` and `pendingNavigator`.
- Rechecked accepted ownership before each attempt and before every delay, stopping deterministically when ownership disappears.
- Extended the production readiness window from three seconds to twenty seconds at 250 millisecond intervals. This covers the existing cleanup coordinator's bounded 13–14 second teardown limits without indefinite polling.
- Preserved generation cancellation on sign-out and disposal, and retained existing terminal, invalid, opened, and already-open completion handling.
- Added no manager-to-NotificationService callback, RTC cleanup change, native change, backend change, or deployment behavior.

## Tests

- App resume before teardown now spans three `pendingTeardown` ticks, teardown claim, temporary Navigator unavailability, and route opening without another resume event.
- Readiness ownership remains active through a simulated four-second teardown, then opens once after Navigator mount.
- A terminal pending invite clears ownership and stops the probe without opening a route.
- Twenty sequential resume-before-teardown cycles each open one route with one RTC setup owner.
- Existing immediate-Navigator, duplicate Accept, terminal, generation, route-busy, and background-cycle tests remain passing.

## Validation

- `flutter analyze`: passed, no issues.
- `flutter test test/call_v2 --no-pub`: passed, 2,264 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`: passed, 3 tests.
- Focused notification ownership tests: passed, 19 tests.
- `git diff --check`: passed.

## Safety

No Agora/RTC/token architecture, engine cleanup coordinator, native PushKit/CallKit code, Firebase/backend code, rules, or deployment configuration changed. No Firebase service was contacted, no TestFlight build was created, and nothing was deployed.

## Physical Follow-up

Install the pushed branch tip on both iPhones and repeat Call 1 followed by background Call 2 Accept during Call 1 teardown, without delivering another foreground event.
