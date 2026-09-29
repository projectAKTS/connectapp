# Next Task — Read-Only Post-Call Teardown Latency Investigation

Branch: `call-v2`

Starting SHA: `cefa58beffb4f1fbcb1acd7a64d961a8813f5e04`

## Accepted Physical Baseline

TestFlight version `1.0.2`, build `202607311859`, completed three sequential
real calls on two iPhones in one app process. Calls A, B, and C all connected
with two-way audio/video and ended normally without a force quit. Exact CallKit
ownership and repeated routing are physically validated at the starting SHA.

The remaining issue is distinct: an immediate outgoing redial can remain
blocked by `Finishing previous call...` for approximately 5-10 seconds, after
which the next call succeeds.

## Goal

Conduct a read-only investigation that identifies which awaited operation or
operations account for the post-call teardown / outgoing-reservation latency.
Do not optimize or alter behavior until timing evidence proves the bottleneck.

## Required Trace

Measure and correlate this exact path:

1. User ends Call A.
2. Firestore and local terminal handling execute.
3. Agora leave/release executes.
4. The engine cleanup gate settles.
5. Exact CallKit end and verification settle.
6. The Flutter call route pops.
7. `hardResetForNewCall` settles.
8. The lifecycle arbiter releases teardown ownership.
9. A new outgoing reservation becomes available.

For every step, identify the current file/function, awaited operations,
ordering (serial or parallel), timeout/delay constants, cancellation rules,
and available runtime or test evidence. Produce a chronological table showing
elapsed or bounded time attributable to each operation.

## Required Conclusions

- State whether the 5-10 second window is proven to originate in one operation
  or a serial combination.
- Distinguish necessary correctness waits from avoidable latency.
- Identify the precise guard that emits `Finishing previous call...`.
- Confirm when outgoing reservation changes from blocked to available.
- Keep the physically validated ownership/routing correction accepted and out
  of scope.
- If existing evidence cannot prove the bottleneck, report the exact
  observability gap and propose a separately authorized diagnostic step. Do
  not add instrumentation in this task.

## Read-Only Scope

- Inspect current source, existing tests, existing diagnostics, and supplied
  physical evidence only.
- Do not modify production code or tests.
- Do not add instrumentation.
- Do not change cleanup timing, retries, timeouts, or ordering.
- Do not modify Agora, CallKit, Firestore, watchdog, Navigator, backend,
  dependencies, or platform configuration.
- Do not deploy, build, or upload TestFlight.
- Do not claim immediate redial fixed.

Agent-loop handoff/state metadata may be updated after the investigation to
record findings; no source implementation is authorized.

## Deliverable

Return a source-grounded teardown chronology, the proven or unproven latency
bottleneck, the exact outgoing reservation release condition, and one narrowly
defined recommended next action. Stop without implementing that action.
