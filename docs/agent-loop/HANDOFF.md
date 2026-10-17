# Final Production Route Push Ownership Guard Handoff

STATUS: `ready_for_review`

STARTING_SHA: `c5528da10fa485a237fd2940fa635acd1609c535`
IMPLEMENTATION_SHA: `1732e261343640481bb90faf87aca9017e872b71`
ENDING_SHA: `SELF`

## Exact Race Assessment

`_diagManager('route_push')` returns a `Future`. Awaiting that future creates an
asynchronous continuation boundary even though `_diagManager` currently has no
internal `await`. Terminal cleanup or a newer call may therefore change the
current session, route attempt, or route owner before `_openCallScreen()`
resumes. The previous production branch called `Navigator.push()` immediately
after resumption without one final ownership check.

Dart executes synchronous code on one isolate without event interleaving. A
final synchronous ownership check immediately before `Navigator.push()` closes
that boundary: once the check succeeds, no other Dart event can alter ownership
before the push invocation.

## Correction

Immediately before production `Navigator.push()`, `_openCallScreen()` now
requires all of the following:

- the exact `_current` session is still the route session;
- the accepted continuation is still current and lifecycle-valid when present;
- `_openingCallRouteAttempt` is the exact attempt token;
- `_callRouteOwner` is the exact owner created for that session.

Any mismatch returns `staleOwnership`. It does not clear or mutate another
call's session, route attempt, or route owner. The existing fake route-recorder
branch is unchanged.

A test-only barrier can pause only the production navigation branch after the
diagnostic await and before the final guard. It is gated by the existing test
runtime and is null/inert in production.

## Files Changed

- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_background_audio_media_integration_test.dart`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

The pre-existing untracked architecture document remains unchanged with
SHA-256 `d33b3bf300a4980807b863d6c4b29465548284b1c6004638dcfa7fbcb2eda0f3`.
Other pre-existing untracked Aider artifacts were also left untouched.

## Production-Path Regression Proof

`production push revalidates ownership after diagnostics before Navigator push`
disables the fake route recorder and installs a real `MaterialApp` Navigator and
observer. A reaches the post-diagnostic/pre-push barrier, terminalizes, and
releases ownership. B then owns a newer connected lifecycle and held route.
After A is released:

- A returns `staleOwnership` through the accepted-recovery result;
- Navigator push count does not increase;
- no `AgoraCallScreen` is created;
- route and RTC owner counters remain zero for A;
- A's sole background media runtime is cleaned;
- B remains the exact current session, lifecycle generation, connected phase,
  and active route owner.

## Validation

- New deterministic production-path regression: 1 passed.
- Full background audio integration file: 12 passed.
- Accepted recovery, route ownership, exact CallKit ownership, physical media,
  foreground recovery, rapid lifecycle, and repeated-call suites: 195 passed.
- Full clean-tree Call V2 suite: 2,366 passed.
- Full `flutter analyze`: passed, no issues.
- Focused analyzer: passed, no issues.
- Formatting check: passed.
- `git diff --check`: passed.
- Dependency diff: none; no platform, backend, or package files changed.
- iOS RunnerTests: not rerun because no native source or native test changed.

The full suite's historical working-tree allowlist audits require a clean tree.
Revision metadata was temporarily stashed and all pre-existing untracked files
were temporarily moved for that validation only, then restored. The architecture
document hash remained identical.

## Safety

No lifecycle architecture, CallKit connected timing, close-screen UX,
Firebase/Firestore transaction protocol, Agora, PushKit, dependencies, backend,
native watchdog, or cleanup-gate behavior changed. No TestFlight build, backend
deployment, or physical call was performed.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Perform independent final source review of the exact pre-push ownership guard.
