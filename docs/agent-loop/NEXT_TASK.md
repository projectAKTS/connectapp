# Next Task — Post-Call Redial Gate Ordering Correction

Branch: `call-v2`

Starting SHA: `2d4882af94e90dc8dfbcc5fbc402a98e6bb65b07`

## Accepted Findings

The historical 5-10 second runtime wait was not causally identified. Source
review nevertheless proved that outgoing reservation remains blocked after the
old route and local Call A ownership are gone while exact-A-only platform
cleanup still completes.

## Authorized Goal

Move only exact-A-scoped native end verification and scoped persisted accepted
recovery clearing outside the outgoing reservation gate. Preserve every
ownership-critical step inside the gate:

1. route closure;
2. active-listener detach or equivalent fencing;
3. timer and callback quiescence;
4. local accepted-recovery invalidation;
5. old session and UI ownership clearing;
6. lifecycle generation verification;
7. atomic pending-incoming claim, otherwise transition to idle.

## Safety Requirements

- Deferred work must capture immutable Call A identity before release.
- Deferred work must never read mutable current-call state to target cleanup.
- Late Call A completion must not end, clear, reset, or mutate Call B.
- Pending incoming ownership retains priority over outgoing redial.
- Exact CallKit ownership remains exact; do not use `endAllCalls()`.
- Keep Firestore terminal semantics, accepted transactions, PushKit routing,
  native UUID propagation, watchdog timing, Navigator architecture, and the
  Agora process engine gate unchanged.

## Required Tests

- blocked exact A native end does not block B reservation;
- blocked exact A persisted-recovery clear does not block B;
- late A cleanup cannot mutate current B;
- pending incoming is claimed before outgoing can reserve;
- stale A generation cannot release B;
- normal teardown still performs exact cleanup and reaches idle;
- all existing exact ownership, notification ownership, lifecycle, recovery,
  Call V2, and iOS Runner tests remain passing.

## Validation

Run Flutter analysis, focused ownership/lifecycle/recovery tests, the complete
Call V2 suite, foreground recovery tests, iOS RunnerTests, `git diff --check`,
and dependency/lockfile diff inspection. Do not build TestFlight, deploy, or
request physical testing in this task.

## Commit And Handoff

Commit the focused implementation and tests, record a `ready_for_review`
handoff, push `origin/call-v2`, and stop. Do not claim that the historical
runtime duration itself was proven.
