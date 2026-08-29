# Review Handoff

Phase: `physical_repeat_call_pending_accept`
Status: `ready_for_review`
Authorized baseline: `6b548b2f4ade470e4b8b02fae9d5517ee0438ec9`
Starting HEAD: `3f2d22789b28027b1ddc76c5b7967f11b1c05b1c`
Implementation commit: `973fc2271a84c44bbe8bcaecfa45e3192732d6a2`

## Root Cause

`handleRecoveredAcceptedInvite()` returned `pendingNavigator` before loading the
authoritative invite or passing native CallKit Accept into lifecycle ownership.
If app resume preceded the native bridge, the readiness probe observed no
ownership and exited. The bridge then recorded no route obligation, so Call 2
could remain on Home with a live native accepted call.

## Correction

- Removed Navigator readiness as a prerequisite for accepted-event ingestion.
- Idle and teardown-blocked native accepts now establish exact-invite,
  generation-scoped accepted route ownership before attempting route work.
- The native bridge kicks the existing single-flight readiness coordinator only
  after ownership exists, closing both resume-before-bridge and
  bridge-before-resume orderings.
- Navigator-unavailable recovery no longer starts the separate accepted-call
  retry timer while durable route ownership exists.
- Route-pending readiness re-reads the authoritative invite. Terminal or missing
  state clears ownership, clears stored recovery, ends matching native CallKit
  state, and returns the lifecycle to idle.
- The bounded readiness deadline deterministically marks a still-open invite
  failed, ends matching native state, clears accepted ownership and recovery,
  and releases the lifecycle instead of orphaning an accepted native call.
- Duplicate native/plugin accepts converge on one continuation, one route open,
  and one RTC setup owner.

## Tests

- Exact physical ordering: Call A teardown, Call B native Accept with no
  Navigator, teardown completion, Navigator mount, one route and RTC owner.
- Resume before the native bridge exits safely; the later bridge records
  ownership, kicks readiness, and opens without a second resume event.
- Native bridge before Navigator/resume retains durable idle-lifecycle route
  ownership and opens once when routing becomes available.
- Authoritative terminal state before route open clears ownership and matching
  native state and cannot be resurrected by a later Navigator mount.
- Readiness deadline leaves no pending ownership or native accepted state and
  settles the lifecycle idle.
- Native/plugin/resume duplicates retain one route/RTC owner.
- Twenty alternating resume-before-bridge and bridge-before-resume background
  cycles each open exactly once.
- Existing accepted/joining, terminal, supersession, generation, and pending
  teardown coverage remains passing.

## Validation

- `flutter analyze`: passed, no issues.
- `flutter test test/call_v2 --no-pub`: passed, 2,268 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`:
  passed, 3 tests.
- Focused notification ownership tests: passed, 23 tests.
- Focused rapid lifecycle-manager tests: passed, 57 tests.
- `git diff --check`: passed.

## Safety

No engine cleanup coordinator, Agora/RTC/token architecture, native
PushKit/CallKit presentation code, Firebase/backend code, rules, or deployment
configuration changed. No Firebase service was contacted, no TestFlight build
was created, and nothing was deployed.

## Physical Follow-up

Install the pushed branch tip on both iPhones and repeat Call 1 followed by
background Call 2 Accept during Call 1 teardown, including the case where app
resume arrives before the native accept bridge.
