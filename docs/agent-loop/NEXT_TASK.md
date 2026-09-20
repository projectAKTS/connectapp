# Accepted Transaction Authority Revision

Starting SHA: `41f8c89d934c698ef0b297867297f77588d1698f`

Physical instrumentation proves accepted native recovery repeatedly times out
in the standalone `callInvites` read before route continuation. Reuse the
existing guarded Firestore accept transaction as the single acceptance trust
boundary and remove mandatory duplicate pre-route reads from native accepted
recovery and its immediate continuation.

Required invariants:

- Exact local accepted ownership is recorded before network work.
- Route opening requires a successful server transaction that validates the
  invite exists, the authenticated user is the recipient, and the status is
  openable.
- The transaction result carries the authoritative payload needed by routing;
  stale cache never authorizes acceptance.
- Recoverable transaction failures retry the same generation without creating
  another route or RTC owner.
- Native terminal/watchdog completion cancels matching retries immediately and
  cannot affect a newer generation.
- Unrelated invite reads remain unchanged.

Add deterministic tests for empty-cache acceptance, standalone-read failure
with transaction success, transaction retry, terminal and wrong-recipient
rejection, stale-cache/server-terminal authority, A/B/C sequential reuse, and
watchdog cancellation during retry.

Do not change native UUID allocation, PushKit/CallKit presentation, Navigator,
Agora/RTC, watchdog duration, backend schema, Firestore rules, dependencies,
deployment, or TestFlight. Do not claim the physical issue is fixed.
