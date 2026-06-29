# Review Handoff

Phase: 3C
Status: revision_required
Accepted Phase 3B checkpoint: `05a5407ab2d77a5f8772ae05bdf3b6a3cffa7a8e`
Failed workflow: `28394453498`
Failed job: `84129480172`

## Exact failure

The baseline/backend gates, formatting, and Flutter analysis passed. Focused Flutter tests reported 73 passed and 1 failed.

Failing test:

`presenter derives display-safe state and actions by lifecycle`

Mismatch at `test/call_v2/call_v2_behavior_test.dart:365`:

- expected `CallLocalPhase.inCall`
- actual `CallLocalPhase.presentingIncoming`

The accepted session manager ignores equal or lower durable snapshot versions. The correction must use increasing versions for lifecycle-transition fixtures rather than weakening monotonicity. The failed workflow discarded the generated Phase 3C files, so the next run must rebuild the complete Phase 3C presenter/view-model work.

V1 remains untouched, V2 remains disabled by default, no production service was contacted, no live setting changed, and nothing was deployed.
