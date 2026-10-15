# Durable Diagnostic Storage Atomicity Revision Handoff

STATUS: `ready_for_review`

STARTING_SHA: `1aeb7c41b5931dd67442b80f838fbc03c825f9ba`
AUTHORIZATION_SHA: `1a48d9c80f7bdfaf1990d9b8a964daddf78cb2ab`
IMPLEMENTATION_SHA: `f3932e66d7d56663bf2744238d155117b2f21948`
ENDING_SHA: `SELF`

## Correction

`CallV2FileDurableDiagnosticStore.write()` now creates a unique temporary file
beside the Application Support target, writes and flushes the complete encoded
snapshot, and then replaces the target with same-directory `File.rename`.
Dart's VM delegates file rename on Apple platforms to POSIX rename; keeping both
paths in one directory gives the iOS filesystem an atomic replacement boundary.
Preparation failures leave the previous target untouched. Failed staging files
are removed asynchronously where possible without replacing the original error.

The recorder now treats `_events` as the last successfully persisted snapshot.
Each append copies that snapshot, applies retention to the candidate, writes the
candidate, and publishes it to `_events` only after the store succeeds. A failed
write therefore remains absent from both the current recorder and a new recorder,
and the next successful write resumes from the last committed sequence.

Record submission remains serialized and fire-and-forget. No synchronous file
operation or diagnostic storage await was added to a call-critical path.

## Files Changed

- `lib/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart`
- `test/call_v2/diagnostics/call_v2_durable_boundary_diagnostics_test.dart`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/STATE.json`

Authorization metadata was committed separately in
`1a48d9c80f7bdfaf1990d9b8a964daddf78cb2ab`.

The pre-existing untracked
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` remains unchanged with SHA-256
`d33b3bf300a4980807b863d6c4b29465548284b1c6004638dcfa7fbcb2eda0f3`.

## Test Proof

- Real temporary-filesystem pre-commit failure preserves the prior valid JSON.
- A deliberately truncated staging file is never exposed at the target path.
- Real same-directory replacement publishes one complete valid snapshot.
- Failed persistence is absent from the current recorder and a new recorder.
- A/B/C history and sequence ordering survive a failed append.
- A later successful append continues at sequence 4 from the committed snapshot.
- Existing retention and fingerprint privacy assertions remain green.
- A blocked store proves `record()` returns before persistence completes.

## Validation

- Focused durable diagnostics: 15 passed.
- Focused CallKit ownership/repeated lifecycle/route ownership: 181 passed.
- Focused background audio/media ownership: 18 passed.
- Foreground recovery: 3 passed.
- Full isolated Call V2 suite: 2,361 passed.
- `flutter analyze`: passed, no issues.
- `git diff --check`: passed.
- Dependency diff: none for `pubspec.yaml`, `pubspec.lock`, `ios/Podfile`, or
  `ios/Podfile.lock`.
- iOS RunnerTests: not rerun because no native source or test changed; the
  reviewed baseline result remains 30 passed, 0 failed.

The full suite's historical working-tree isolation audits were run after the
implementation commit. The architecture document was moved outside the
repository only for that run and restored with an identical SHA-256.

## Safety

No native CallKit, accepted recovery, Firestore transaction, timeout, retry,
Agora/media ownership, engine cleanup, PushKit/APNs, backend, dependency, or
audio/video behavior changed. No backend/Firebase deployment, TestFlight build,
or physical call was performed.

ROOT_CAUSE_CLAIM: `NONE`

## Next

Review the durable storage atomicity and committed-snapshot correction before
authorizing any TestFlight build.
