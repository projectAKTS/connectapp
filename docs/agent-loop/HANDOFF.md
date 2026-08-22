# Review Handoff

Phase: `physical_repeat_call_pending_accept`
Status: `ready_for_review`
Authorized baseline: `6b548b2f4ade470e4b8b02fae9d5517ee0438ec9`
Starting HEAD: `37a6d6c9587a6a6aecd0e9016aa4b65dd8023466`
Implementation commit: `ac341289a1add19b70b0352e8d95fee3805a2f25`

## Root Cause

A second incoming invite could be queued while the previous call was ending, but a native CallKit Accept for that queued invite was treated as a duplicate before incoming UI ownership existed. The accepted recovery path consequently returned failure and discarded the user's accepted intent, so teardown completed without opening the second call route.

## Correction

- Added generation-scoped pending accepted-intent ownership to the lifecycle arbiter and session manager.
- Native and plugin Accept duplicates now converge on one durable pending intent without scheduling network recovery retries.
- Previous-call teardown atomically claims the exact pending invite and directly continues through the existing idempotent acceptance and route-opening path.
- Pending accepted continuation permits authoritative `ringing`, `accepted`, and `joining` states; terminal or missing invites are closed without opening a route.
- Supersession, terminal handling, sign-out, hard reset, and successful route opening clear only the matching accepted intent.
- Safe diagnostics expose booleans and counters only; no invite identifiers or payloads were added.

## Tests

- Exact physical sequence: Call A teardown, Call B pending, native Accept, then automatic single route/RTC ownership after teardown.
- Accept before Firestore candidate and Firestore candidate before Accept.
- Native/plugin duplicate Accept delivery in both orders without retry scheduling.
- `accepted` and `joining` authoritative status before pending claim.
- Terminal-before-claim and superseded-pending cleanup.
- Twenty sequential end/immediate-redial cycles, each producing one route and one RTC setup owner.
- Generation transfer, stale-generation rejection, and idempotent accepted-intent recording.

## Validation

- `flutter analyze`: passed, no issues.
- `flutter test test/call_v2 --no-pub`: passed, 2,254 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`: passed, 3 tests.
- Focused lifecycle arbiter tests: passed, 50 tests.
- Focused rapid lifecycle manager tests: passed, 52 tests.
- Focused notification ownership tests: passed, 14 tests.
- `git diff --check`: passed.

The initial full-suite run against the intentionally dirty implementation tree triggered historical tests that assert phase-specific allowed dirty files. After committing the scoped implementation, the required clean-tree run passed all 2,254 tests.

## Safety

No engine-cleanup policy, RTC/token architecture, native code, Firebase/backend code, rules, or deployment configuration changed. No Firebase service was contacted, no TestFlight build was created, and nothing was deployed.

## Physical Follow-up

Install a build containing the implementation commit on both iPhones and repeat Call 1 followed immediately by Call 2 Accept while Call 1 teardown is still completing.
