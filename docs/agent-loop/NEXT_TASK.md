# Active Task — Phase 3A Revision

Branch: `call-v2`
Accepted backend checkpoint: `83933165d7741f06c6e47dcd94e8dbd2d92a6462`
Starting review baseline: `421b761ea653d773e589c55d7a9b9b534bf29b3b`
Implementation commit message: `feat(call-v2): complete Flutter V2 client groundwork`

## Latest failure evidence

Guarded workflow run `28348336472` rebuilt the requested Phase 3A files and passed backend checks, deployment validation, rules tests, three emulator runs, changed-file scope, and Dart formatting. Validation then stopped at:

```bash
flutter analyze lib/call_v2 test/call_v2
```

The retained artifact reports exactly three analyzer issues:

1. Unused import `domain/participant_media_state.dart` in `lib/call_v2/call_session_manager_v2.dart`.
2. Unused field `_callApi` in `lib/call_v2/call_session_manager_v2.dart`.
3. Unused import `domain/call_snapshot.dart` in `lib/call_v2/call_v2_api.dart`.

The failed workflow discarded its uncommitted implementation, so rebuild the complete Phase 3A groundwork from the current branch. This is not a warnings-only task. Preserve the strict parser already accepted. Make the manager use its injected callable API for serialized commands, and leave zero analyzer issues.

## Required result

Create the isolated, disabled-by-default Flutter Call V2 foundation beside V1. Do not connect it to app startup, routes, UI, Firestore listeners, Agora, native call handling, messaging, or live services.

Allowed files only:

- `lib/call_v2/**`
- `test/call_v2/**`
- `docs/call-v2/**`
- `pubspec.yaml` and `pubspec.lock` only if genuinely required

Implement and test:

- Immutable lifecycle, participant-media, role, local-phase, public-call, and public-participant models.
- Strict public parsing requiring `callSystem == "v2"`, valid IDs/version, distinct caller and callee, and an exact two-member participant set equal to caller/callee. Reject malformed identities, roles, enum values, timestamps, non-V2 data, and private operational fields.
- An injected callable transport/API with exact names: `startCallV2`, `acceptCallV2`, `declineCallV2`, `cancelCallV2`, `endCallV2`, `reportParticipantMediaV2`, `renewActiveCallLeaseV2`.
- Request shapes that cannot send authenticated UID, staff/rollout data, cohort data, lock/fencing data, or private task/command identity.
- Controlled client error normalization without raw backend/provider details.
- `CallSessionManagerV2` as the only local owner: one nonterminal call, injected snapshots, stale-version dedupe, deterministic local phases, serialized duplicate commands, no invented durable transitions, deterministic idempotent terminal cleanup, no global singleton.
- `CallNavigationCoordinatorV2` as an intent-only boundary: no `Navigator`, one open intent per call/version, deterministic close intent, and no private identifiers.
- A feature gate defaulting to false; disabled operation makes no transport call and creates no session ownership.
- `docs/call-v2/PHASE_3A_FLUTTER_CLIENT_GROUNDWORK.md` covering V1 isolation, public-only parsing, command boundary, ownership, navigation intents, disabled default, and deferred integrations.

Tests must cover accepted and rejected parsing, private-field exclusion, exact callable names/shapes, forbidden fields, disabled gate, single ownership, stale snapshots, local phases, cleanup idempotence, duplicate-command serialization, failure behavior, navigation dedupe, and zero real service/network contact.

## Validation

Run all of the following and finish only when each passes:

```bash
flutter pub get
dart format lib/call_v2 test/call_v2
dart format --output=none --set-exit-if-changed lib/call_v2 test/call_v2
flutter analyze lib/call_v2 test/call_v2
flutter test test/call_v2
```

The existing backend regression suite in the workflow must also remain green. Do not modify V1, backend code, native code, Firebase configuration, rules, indexes, workflows, `AGENTS.md`, or `docs/agent-loop/**`. Do not deploy, commit, or push from the builder.

## Handoff

Report exact changed files, implemented contracts, focused Flutter test count/results, backend regression results, remaining risks, and confirm: V1 untouched, gate defaults false, no live service contacted, no live setting changed, and nothing deployed.