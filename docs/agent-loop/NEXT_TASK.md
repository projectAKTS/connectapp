# Active Task — Phase 3B Client Harness Groundwork

Branch: `call-v2`
Accepted Phase 3A checkpoint: `009a1f372fabe26fe10394519ff47739788d982a`
Accepted Phase 3A workflow: `28369246060`
Phase 3A implementation commit message: `feat(call-v2): add Flutter V2 client groundwork`

## Review decision

Phase 3A is accepted. Exact review confirmed the implementation corrected the rejected client contracts while keeping the work bounded to disabled, non-production Call V2 client groundwork.

Accepted Phase 3A properties:

- `CallV2RequestContext` no longer contains or serializes `actorUid` or authenticated identity.
- Callable request payloads are limited to safe client fields such as `callId`, `version`, and media reporting fields.
- `domain/call_v2_models.dart` is now harmless exports only; the accepted domain contract remains authoritative.
- Local phase names remain exactly `idle`, `presentingIncoming`, `outgoingRinging`, `openingCallRoute`, `inCall`, and `closing`.
- `CallSessionManagerV2` derives caller/callee ringing phase from an injected local participant role without sending that role as authentication authority.
- Duplicate in-flight command taps are suppressed so the same command key produces one transport request.
- Terminal cleanup clears local ownership and returns to `idle` idempotently.
- `CallNavigationCoordinatorV2` is stateful and dedupes open and close intents without touching `Navigator` or existing routes.
- Errors use a controlled client error-code contract instead of raw provider messages.
- Workflow validation passed backend checks, deployment-readiness validation, Firestore rules tests, three emulator runs, Flutter format/analyze/tests, and `git diff --check`.

## Phase 3B goal

Build a small disabled-by-default Flutter Call V2 client harness around the accepted Phase 3A primitives. This phase must remain non-production and must not wire startup, existing routes, native call stacks, push, Firestore listeners, Agora, CallKit, PushKit, FCM, or live Firebase.

The harness should make the Phase 3A primitives easier to exercise from tests and future UI work without making the feature reachable in the app.

## Required work

1. **Create a disabled client harness facade.**
   - Add a small Call V2 client/controller/facade under `lib/call_v2/**` that composes:
     - `CallV2FeatureGate`
     - `CallV2Api`
     - `CallSessionManagerV2`
     - `CallNavigationCoordinatorV2`
   - The harness must be inert when the feature gate is false.
   - The harness must expose only testable methods for injecting public snapshots and invoking safe commands.
   - It must not subscribe to Firestore, call startup code, register routes, request native permissions, or contact real services by default.

2. **Preserve authentication and request-shape safety.**
   - Do not add `actorUid`, `authenticatedUid`, raw `uid`, staff/rollout/cohort fields, allowlists, salts, percentages, fencing/lock fields, task IDs, command IDs, or private server authority to client request payloads.
   - Do not serialize local participant role as authenticated authority.
   - Continue to rely on server-side Firebase Auth for identity.

3. **Preserve ownership, monotonicity, and navigation behavior.**
   - Equal/lower snapshots must remain ignored for the same call.
   - A terminal snapshot must not be replaced by lower/equal nonterminal data.
   - A different call must remain ignored while a nonterminal call is owned.
   - Terminal cleanup must clear local ownership and remain idempotent.
   - Navigation intents must stay deduped and must not call `Navigator` or existing routes.

4. **Add behavioral tests for the harness.**
   - Feature gate disabled: injected snapshots and commands do nothing and no transport call is made.
   - Feature gate enabled: public snapshots derive expected local phase and safe commands produce exactly one safe transport request.
   - Duplicate command taps through the harness still produce one in-flight request.
   - Terminal snapshot through the harness produces a close intent once, cleanup clears ownership, and repeated cleanup/close does not emit duplicates.
   - The harness must use fake transports only; no real network, Firebase, native, Agora, CallKit, PushKit, FCM, or route access.

5. **Keep Phase 3A tests intact.**
   - Do not weaken existing Phase 3A request-shape, parser, manager, navigation, or error-code tests.
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

Report exact changed files and behavioral test results. Explicitly confirm disabled default, V1 isolation, no client-supplied authenticated UID, safe request shapes, duplicate-command suppression, terminal cleanup, navigation dedupe, fake-only tests, and no deployment/live contact.