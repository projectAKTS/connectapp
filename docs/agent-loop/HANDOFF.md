# Phase 3B Handoff

Status: task_ready
Accepted Phase 3A checkpoint: `009a1f372fabe26fe10394519ff47739788d982a`
Failed Phase 3B run: `28385628175`
Failed job: `84099412879`

## Failure classification

The failed run did not demonstrate a Phase 3B client defect. The unchanged backend emulator suite failed on the concurrency test:

`timeout lifecycle races produce one authoritative outcome`

The assertion expected a fulfilled race participant but received a rejected result. This happened before Flutter analysis and Flutter tests, and generated client changes were discarded.

## Process hardening completed

- Added `.github/scripts/validate-call-v2-agent-loop.py` as a fail-closed transition/task preflight.
- The preflight validates phase, runnable status, authoritative task identity, task fingerprint, accepted checkpoint ancestry, starting SHA ancestry, trigger freshness, and absence of a hard-coded phase lock.
- Added backend baseline validation before Codex so pre-existing failures block before implementation work begins.
- Added one bounded retry for an unchanged emulator suite; repeated failure remains blocking.
- Baseline failures now keep the implementation task `task_ready` and are reported separately from implementation revisions.
- Post-implementation failures now record the exact failed stage.

Phase 3B remains the authoritative active task. V1 is untouched, V2 remains disabled by default, no production service was contacted, no live configuration changed, and nothing was deployed.
