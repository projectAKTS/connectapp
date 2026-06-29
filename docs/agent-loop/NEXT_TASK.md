# Active Task — Phase 3C Client View-Model Groundwork

Branch: `call-v2`
Accepted Phase 3B checkpoint: `05a5407ab2d77a5f8772ae05bdf3b6a3cffa7a8e`
Accepted Phase 3B workflow: `28386385870`
Phase 3B implementation commit message: `feat(call-v2): implement phase 3B task`

## Latest focused failure

Workflow run `28394453498` passed the transition preflight, unchanged backend baseline, backend checks, deployment-readiness validation, Firestore rules tests, three emulator runs, formatting, and Flutter analysis. It failed only at:

```bash
flutter test test/call_v2
```

Exact failing test:

`presenter derives display-safe state and actions by lifecycle`

Exact mismatch at `test/call_v2/call_v2_behavior_test.dart:365`:

- expected: `CallLocalPhase.inCall`
- actual: `CallLocalPhase.presentingIncoming`

The workflow discarded the generated Phase 3C implementation after failure. Rebuild the complete Phase 3C task from the accepted Phase 3B checkpoint.

The accepted manager intentionally ignores equal or lower durable snapshot versions. Therefore, lifecycle-transition tests and fixtures must use monotonically increasing call versions when moving from ringing to accepted, active, or terminal. Do not weaken snapshot monotonicity, ownership, or terminal protections to make the test pass. Ensure the presenter derives state from the manager's accepted authoritative snapshot after each increasing-version injection.

## Review decision

Phase 3B is accepted. Exact review confirmed the implementation stayed bounded to disabled, non-production Call V2 client harness groundwork.

Accepted Phase 3B properties:

- `CallV2Harness` composes `CallV2FeatureGate`, `CallV2Api`, `CallSessionManagerV2`, and `CallNavigationCoordinatorV2`.
- The harness is inert when the feature gate is false.
- Harness methods expose only testable public-snapshot injection, safe command invocation, navigation-intent derivation, and terminal cleanup.
- Request payloads remain limited to safe client fields such as `callId`, `version`, `mediaState`, and `mediaVersion`.
- No client-supplied authenticated UID, raw UID, rollout authority, task IDs, command IDs, lock fields, or private server authority were added.
- Duplicate in-flight command taps remain suppressed.
- Terminal cleanup clears local ownership idempotently.
- Navigation intents remain deduped and do not touch `Navigator` or existing routes.
- Tests use fake transports only.
- Workflow validation passed backend baseline, backend checks, deployment-readiness validation, Firestore rules tests, three emulator runs, Flutter format/analyze/tests, and `git diff --check`.

## Phase 3C goal

Add a small disabled-by-default, pure Dart Call V2 client view-model/presenter layer around the accepted harness primitives. This phase should make future UI work easier to test by deriving display-safe state and allowed user actions from public snapshots and local phase, without wiring any real UI, app startup, routes, native call stacks, push, Firestore listeners, Agora, CallKit, PushKit, FCM, or live Firebase.

The result must remain non-production and unreachable from the existing app.

## Required work

1. **Create a pure Call V2 view-model/presenter.**
   - Add a small presenter/view-model under `lib/call_v2/**` that consumes the accepted harness state or accepted domain objects.
   - It may derive display-safe values such as local phase, title/status keys, whether accept/decline/end/cancel/report-media actions should be enabled, and whether an open or close navigation intent is pending.
   - It must not import Flutter widgets, `Navigator`, app routes, Firebase, Agora, CallKit, PushKit, FCM, permissions, platform channels, or production configuration.
   - It must not subscribe to Firestore, call startup code, register routes, request native permissions, or contact real services.

2. **Preserve authentication and request-shape safety.**
   - Do not add `actorUid`, `authenticatedUid`, raw `uid`, staff/rollout/cohort fields, allowlists, salts, percentages, fencing/lock fields, task IDs, command IDs, or private server authority to client request payloads.
   - Do not serialize local participant role as authenticated authority.
   - Continue to rely on server-side Firebase Auth for identity.

3. **Preserve ownership, monotonicity, command, and navigation behavior.**
   - Equal/lower snapshots must remain ignored for the same call.
   - A terminal snapshot must not be replaced by lower/equal nonterminal data.
   - A different call must remain ignored while a nonterminal call is owned.
   - Duplicate command taps through the harness/presenter must still produce one in-flight transport request.
   - Terminal cleanup must clear local ownership and remain idempotent.
   - Navigation intents must stay deduped and must not call `Navigator` or existing routes.

4. **Add behavioral tests for the presenter/view-model.**
   - Feature gate disabled: derived state remains idle/inert and actions do not call transport.
   - Feature gate enabled: public snapshots derive expected local phase and display-safe state.
   - Allowed-action derivation matches ringing/accepted/active/terminal phases for caller and callee roles.
   - Lifecycle-transition fixtures must increment durable snapshot versions; equal/lower versions must continue to be tested as ignored.
   - Duplicate command taps through the presenter still produce one safe transport request.
   - Terminal snapshot through the presenter produces one close intent, cleanup clears ownership, and repeated cleanup/close does not emit duplicates.
   - Tests must use fake transports only; no real network, Firebase, native, Agora, CallKit, PushKit, FCM, widgets, routes, or platform access.

5. **Keep Phase 3A and 3B tests intact.**
   - Do not weaken existing request-shape, parser, manager, navigation, harness, or error-code tests.
   - Add tests rather than deleting behavioral coverage.

## Allowed files

- `lib/call_v2/**`
- `test/call_v2/**`
- `docs/call-v2/**`
- `docs/agent-loop/**`
- `pubspec.yaml` and `pubspec.lock` only when genuinely required

## Validation

Run and pass all of these before marking ready for review:

```bash
flutter pub get
dart format lib/call_v2 test/call_v2
dart format --output=none --set-exit-if-changed lib/call_v2 test/call_v2
flutter analyze lib/call_v2 test/call_v2
flutter test test/call_v2
```

Backend deployment-readiness, rules, emulator, syntax, and whitespace validations must remain green if the workflow includes them.

## Safety

V1 must remain untouched. The V2 feature gate must default false. Do not wire app startup, production routes, Firestore listeners, Agora, CallKit, PushKit, FCM, native code, production Firebase, IAM, OIDC, queues, secrets, kill switches, rollout configuration, or live services. Do not deploy, enable switches, change live configuration, contact production services, or invent production values.

## Handoff

Report exact changed files and behavioral test results. Explicitly confirm disabled default, V1 isolation, no client-supplied authenticated UID, safe request shapes, duplicate-command suppression, terminal cleanup, navigation dedupe, fake-only tests, monotonically increasing lifecycle-test versions, and no deployment/live contact.