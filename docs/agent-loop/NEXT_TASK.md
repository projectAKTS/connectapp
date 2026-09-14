# Accepted Call Identity Provenance Revision

Starting SHA: `9087e450936aeecbf11c2836ae0e4196065c11b4`

Physical Call 2 still reaches `acceptedRecoveryCoalescedSameCall` before local
accepted ownership despite having a new native CallKit presentation. Trace the
exact CallKit ID from native creation through NotificationService, retries,
CallSessionManager ownership, routed session, and terminal cleanup. Identify
the first path that can lose or reconstruct the exact ID.

Also trace every await between `acceptedRecoveryOwnershipRequested` and
`acceptedOwnershipRecorded`, and ensure retry ownership is invalidated after
the exact accepted native call is terminal and verified ended.

Required invariants:

- Different non-empty exact CallKit IDs are always distinct, even when the
  invite ID is reused.
- Invite fallback is allowed only when at least one exact ID is absent.
- Stored recovery and retries preserve a known exact accepted ID.
- A distinct exact call acquires recovery ownership before delayed network I/O.
- Terminal verification cancels retries/futures for that exact generation.
- Exact identity survives through routed terminal cleanup.

Add deterministic integration-shaped tests for native bridge provenance,
same-invite/different-exact-ID ownership, stored/retry reconstruction, fallback
compatibility, delayed authoritative reads, post-terminal retry cancellation,
and A/B/C sequential reuse in one process.

Do not change Agora, PushKit presentation, the native watchdog or its timeout,
native CallKit termination, Navigator architecture, Firebase/backend,
Firestore schema/rules, dependencies, or deployment. Do not build or deploy,
and do not claim the physical issue is fixed.
