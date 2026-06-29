# Phase 3A Flutter Client Groundwork

This phase adds a disabled-by-default Flutter Call V2 foundation beside the existing V1 code.

## Scope

- V1 remains untouched.
- No startup wiring, route wiring, listener wiring, Agora wiring, native call wiring, messaging wiring, or live service wiring is added.
- The new client code stays isolated under `lib/call_v2/**` and `test/call_v2/**`.

## Contracts

- Public parsing only accepts `callSystem == "v2"`.
- Parsing requires valid IDs, version, distinct caller and callee identities, and an exact two-member participant set.
- Malformed identities, roles, enum values, timestamps, non-V2 data, and private operational fields are rejected.
- Callable transport entry points are named `startCallV2`, `acceptCallV2`, `declineCallV2`, `cancelCallV2`, `endCallV2`, `reportParticipantMediaV2`, and `renewActiveCallLeaseV2`.
- Request payloads exclude authenticated UID, staff or rollout data, cohort data, lock or fencing data, and private task or command identity.
- `CallSessionManagerV2` owns one local call at a time, deduplicates stale snapshots, serializes duplicate commands, and performs deterministic terminal cleanup.
- `CallNavigationCoordinatorV2` emits intent objects only and does not depend on `Navigator`.
- `CallV2FeatureGate` defaults to disabled.

## Deferred integrations

The new groundwork intentionally defers app startup, UI, Firestore, Agora, native call handling, and live backend integration until a later phase.

