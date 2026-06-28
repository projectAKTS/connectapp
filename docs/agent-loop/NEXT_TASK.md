# Active Task — Phase 3A

Branch: `call-v2`
Accepted backend checkpoint: `83933165d7741f06c6e47dcd94e8dbd2d92a6462`
Implementation commit message: `feat(call-v2): add Flutter V2 client groundwork`

## Revision focus for the next retry

The retained validation artifact from workflow run `28336086589` shows the prior implementation passed backend validation and failed in the focused Flutter parser tests. Do not repeat a broad rewrite. Make the smallest correction needed in the Phase 3A Flutter client groundwork.

Required parser correction:

- A public call snapshot is valid only when `callerUid` and `calleeUid` are both present and different.
- The public participant map/list must contain exactly two participant UIDs.
- The exact participant UID set must be `{callerUid, calleeUid}`. No extra UID, missing UID, duplicate role, placeholder ID, or swapped role mismatch is acceptable.
- The caller participant must have role `caller`; the callee participant must have role `callee`.
- Add or fix focused parser tests proving same caller/callee, wrong participant IDs, missing caller/callee participant, and duplicate caller/callee roles all fail closed.

Keep all existing Phase 3A requirements below in force.

## Goal

Create the isolated Flutter client foundation for Helperly Call System V2 beside the legacy call system. Keep it unused and disabled by default. Do not connect routes, UI, Agora, CallKit, FCM, Firestore listeners, or production Firebase yet.

## Allowed files

- `lib/call_v2/**`
- `test/call_v2/**`
- `docs/call-v2/**`
- `pubspec.yaml` and `pubspec.lock` only when genuinely required

Do not modify existing legacy call files, app startup, routes, native iOS/Android code, backend functions, Firebase config, rules, indexes, or workflows.

## Required architecture

Add a small, testable V2 client package containing:

1. **Domain enums and immutable models** matching the accepted backend contract:
   - lifecycle: `ringing`, `accepted`, `active`, `completed`, `declined`, `cancelled`, `missed`, `failed`
   - participant media: `notJoined`, `preparing`, `joining`, `joined`, `reconnecting`, `disconnected`, `left`, `mediaFailed`
   - role: caller/callee
   - local phase: `idle`, `presentingIncoming`, `outgoingRinging`, `openingCallRoute`, `inCall`, `closing`

2. **Strict public snapshot parsing** for `calls/{callId}` and participant documents:
   - require `callSystem == "v2"`
   - require a valid call ID, version, caller UID, callee UID, and exact two distinct participant UIDs
   - reject unknown lifecycle/media values
   - parse optional Firestore timestamps without exposing server-only operational data
   - ignore or reject server-only operational fields such as lease claims, commands, callOps, outbox task IDs, and dispatch diagnostics
   - never infer durable state from local media events

3. **Callable API boundary**:
   - exact callable names: `startCallV2`, `acceptCallV2`, `declineCallV2`, `cancelCallV2`, `endCallV2`, `reportParticipantMediaV2`, `renewActiveCallLeaseV2`
   - do not include authenticated UID, staff status, rollout mode, percentage, salt, allowlist, or cohort data in requests
   - expose a transport interface for tests
   - production Firebase Functions transport may be implemented but must not execute during import or tests
   - normalize callable errors into controlled client error codes without exposing raw server/provider details

4. **Single local owner skeleton** named clearly as `CallSessionManagerV2`:
   - at most one active nonterminal call locally
   - accept public call and participant snapshots through injected methods; no direct Firestore dependency yet
   - dedupe stale snapshots by call ID/version
   - derive local phase from server-authoritative lifecycle plus current user role
   - terminal snapshot clears local ownership through a deterministic closing/idle sequence
   - serialize command intents so duplicate taps do not issue parallel commands
   - command failure must not invent a lifecycle transition
   - expose immutable state/listenable behavior using existing Flutter patterns; no global singleton

5. **Navigation ownership boundary**:
   - define a `CallNavigationCoordinatorV2` interface/value contract that emits normalized route intents only
   - do not call `Navigator`, open a route, or touch existing navigation
   - ensure one route-open intent per call/version and deterministic close intent on terminal state

6. **Feature gate**:
   - constructor-injected or compile-time-safe gate defaulting to false
   - no client-visible production rollout configuration
   - disabled state performs no Firebase call and creates no session ownership

## Tests

Add focused pure/unit tests proving at minimum:

- every accepted lifecycle/media value parses and unknown values fail closed
- malformed participant sets and non-V2 documents are rejected
- private operational fields never appear in public models or API results
- callable names and request shapes are exact
- auth UID and rollout/staff data cannot be sent by the client boundary
- disabled gate makes no transport call
- only one local active call is owned
- stale/lower-version snapshots are ignored
- accepted/active/terminal snapshots derive deterministic local phases
- terminal cleanup is idempotent
- duplicate command taps produce one in-flight transport request
- failed commands do not change durable lifecycle locally
- navigation intents are deduped and contain no private identifiers
- no production Firebase, Agora, CallKit, FCM, or network service is contacted

## Documentation

Create `docs/call-v2/PHASE_3A_FLUTTER_CLIENT_GROUNDWORK.md` describing isolation from V1, public-data-only parsing, command boundary, manager ownership, navigation intent boundary, disabled-by-default behavior, and explicit exclusions for later phases.

## Validation

Use the repository Flutter SDK requirements and run:

```bash
flutter pub get
dart format lib/call_v2 test/call_v2
dart format --output=none --set-exit-if-changed lib/call_v2 test/call_v2
flutter analyze lib/call_v2 test/call_v2
flutter test test/call_v2
```

Formatting generated Dart code is part of implementation, not a reason to discard otherwise valid work. The existing backend validation workflow must continue passing. Do not deploy or contact production services.

## Handoff

Report exact files, domain models, parser behavior, callable transport contract, session-manager behavior, navigation-intent behavior, focused Flutter test count/results, backend regression results, and remaining risks. Confirm V1 was untouched, feature gate defaults false, no production service was contacted, no live setting changed, and nothing was deployed.
