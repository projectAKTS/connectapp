# Active Task — Phase 3A Validation Revision

Branch: `call-v2`
Accepted backend checkpoint: `83933165d7741f06c6e47dcd94e8dbd2d92a6462`
Rejected implementation: `ca57d4ad6c6878f0424783f8d94b8493390a1146`
Rejected workflow: `28348917545`
Failed retry workflows: `28350979605`, `28353584185`
Implementation commit message: `feat(call-v2): complete Flutter V2 client groundwork`

## Review and validation decision

Phase 3A is not accepted. Workflow `28348917545` passed, but exact code review found behavioral contract defects that the generated tests did not detect. Retry workflow `28350979605` failed during the combined validation step and discarded its uncommitted implementation. Retry workflow `28353584185` generated implementation changes and entered the same guarded validation block, then the workflow recorded a validation failure and discarded the implementation before commit. Rebuild the complete Phase 3A correction from the current branch.

The latest workflow failure is from run `28353584185`, job `83991409108`. The job steps show `Run backend and Flutter validation` completed with the failure path active, `Upload validation failure log` succeeded, and `Record validation failure` failed the job intentionally after writing the retained artifact. The retained artifact is `phase3a-validation-28353584185` from workflow run `28353584185`.

The validation command block to reproduce is exactly:

```bash
cd connect_functions
node --version
npm run check:call-v2
npm run validate:call-v2:deployment
npm run test:call-v2:rules
npm run test:call-v2:emulator
npm run test:call-v2:emulator
npm run test:call-v2:emulator
node --check index.js
cd ..
dart format --output=none --set-exit-if-changed lib/call_v2 test/call_v2
flutter analyze lib/call_v2 test/call_v2
flutter test test/call_v2
git diff --check
```

Use retained artifacts only as diagnostic evidence. Do not treat any prior generated code as accepted.

## Required focused corrections

1. **Use the accepted domain contract instead of a parallel duplicate model tree.**
   - Reuse the existing accepted files such as `domain/call_snapshot.dart`, `domain/call_lifecycle.dart`, `domain/participant_media_state.dart`, and `domain/call_local_phase.dart`.
   - Remove `domain/call_v2_models.dart` unless it is reduced to harmless exports with no duplicate enums/models/parser.
   - Preserve the strict existing parser based on `participantUids` and exact caller/callee participant identities. Do not replace it with a parser that accepts only an embedded participant list.
   - The exact local phase names remain: `idle`, `presentingIncoming`, `outgoingRinging`, `openingCallRoute`, `inCall`, `closing`.

2. **Remove authenticated identity from callable request data.**
   - `CallV2RequestContext.actorUid` and serialized `actorUid` are forbidden.
   - Do not serialize authenticated UID, staff/rollout/cohort data, allowlists, salts, percentages, fencing/lock data, or private task/command identities.
   - Authentication identity must come from Firebase Auth on the server, not from the client request.
   - Add exact request-shape tests that fail for `actorUid`, `authenticatedUid`, `uid`, `staff`, `rolloutMode`, `percentage`, `salt`, `allowlist`, `cohort`, `fencingToken`, `lockClaim`, task IDs, and command IDs.

3. **Make `CallSessionManagerV2` satisfy the ownership contract.**
   - Inject the current local participant role for phase derivation, but never send it as authenticated authority.
   - `ringing` derives `outgoingRinging` for caller and `presentingIncoming` for callee.
   - `accepted` derives `openingCallRoute`; `active` derives `inCall`; terminal state derives `closing`, followed by deterministic cleanup to `idle`.
   - Ignore equal or lower versions for the same call. Never allow a lower/equal nonterminal snapshot to replace a terminal snapshot.
   - While owning a nonterminal call, ignore/reject a different call.
   - Terminal cleanup must actually clear local ownership and be idempotent.
   - Duplicate command taps with the same command key must share/suppress the in-flight operation and result in exactly one transport request. The existing queued-command key must not be unused.
   - A failed command must not change the durable snapshot or invent a lifecycle transition.

4. **Make `CallNavigationCoordinatorV2` truly dedupe intents.**
   - It must retain local dedupe state or expose a stateful contract.
   - Emit at most one open intent per call/version.
   - Emit one deterministic close intent for terminal state and suppress repeats.
   - Never call `Navigator` or existing routes.

5. **Use controlled error codes.**
   - Replace a generic message-only wrapper with a small controlled error-code contract.
   - Never expose raw server/provider messages, stack traces, or private data.

6. **Replace weak tests with behavioral tests.**
   - The rejected test expected two transport calls for duplicate accept taps; the correct expectation is exactly one in-flight request.
   - The rejected navigation test did not call `openIntentFor` twice and therefore did not test dedupe.
   - Add tests for caller/callee ringing phases, equal/lower snapshot rejection, terminal monotonicity, different-call ownership rejection, actual terminal ownership clearing, failed-command durability, exact callable names, exact safe payloads, controlled error codes, and no real network/service contact.

## Allowed files

- `lib/call_v2/**`
- `test/call_v2/**`
- `docs/call-v2/**`
- `pubspec.yaml` and `pubspec.lock` only when genuinely required

## Validation

Run and pass all of these in the workflow:

```bash
flutter pub get
dart format lib/call_v2 test/call_v2
dart format --output=none --set-exit-if-changed lib/call_v2 test/call_v2
flutter analyze lib/call_v2 test/call_v2
flutter test test/call_v2
```

The existing backend validation, deployment-readiness validation, Firestore rules tests, three emulator runs, syntax check, and `git diff --check` must remain green.

## Safety

V1 must remain untouched. The V2 feature gate must default false. Do not wire startup, routes, Firestore listeners, Agora, CallKit, PushKit, FCM, native code, or production Firebase. Do not deploy, enable switches, change live configuration, contact production services, or invent production values.

## Handoff

Report exact changed files and behavioral test results. Explicitly confirm removal of client-supplied authenticated UID, exact local phase names, one-request duplicate-command behavior, terminal ownership clearing, navigation dedupe, V1 isolation, disabled default, and no deployment/live contact.
