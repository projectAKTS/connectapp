# Physical Validation Handoff

STATUS: `task_ready`

REVIEWED_SOURCE_SHA: `cefa58beffb4f1fbcb1acd7a64d961a8813f5e04`
ENDING_SHA: `SELF`

## TestFlight Build

- Version: `1.0.2`
- Build: `202607311859`
- Devices: two real iPhones
- `CALL_V2_REAL_FLOW_ENABLED=true`
- `CALL_V2_REAL_FLOW_DEV_CALLABLE=true`
- `CALL_V2_BUILD_COMMIT=cefa58beffb4f1fbcb1acd7a64d961a8813f5e04`

## Physical Result

Three sequential real calls completed successfully in the same app process.

| Result | Outcome |
| --- | --- |
| Call A | PASS |
| Call B | PASS |
| Call C | PASS |
| Repeated-call core | PHYSICAL PASS |
| A -> B -> C | PHYSICAL PASS |
| Exact CallKit ownership / repeated routing | PHYSICAL PASS |
| Force quit required | NO |

For all three calls, native incoming UI appeared, Accept succeeded, the
Helperly call screen opened, RTC connected, two-way video and audio worked,
and the call ended normally. The historical second-call routing/join failure
was not reproduced.

## Remaining Behavior

Immediate redial is not yet a pass. Directly after a call ends, a new outgoing
attempt can show `Finishing previous call...` (or the equivalent lifecycle
block) for approximately 5-10 seconds. After that delay, the next call starts
and succeeds normally.

This is classified as post-call teardown / outgoing-reservation latency. It is
not classified as a recurrence of the old Call 2 ownership, routing, or force-
quit correctness failure.

## Scope

This update records user-supplied physical validation only. No production
code, tests, call timing, Agora, CallKit, Firestore, watchdog, backend, or
deployment behavior changed.

## Next

Perform the authorized read-only teardown-latency investigation in
`docs/agent-loop/NEXT_TASK.md`. Measure the complete Call A end-to-next-outgoing
reservation path and identify the exact awaited operation or operations behind
the observed 5-10 second window. Do not optimize until evidence establishes
the bottleneck, and do not reopen the validated exact ownership correction.
