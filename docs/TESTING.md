# Testing

## Where Each Kind Of Test Runs

| Tests | Local | CI |
|---|---|---|
| Flutter unit and widget tests (`test/`) | `flutter test --exclude-tags test-mode` | `App Flutter Tests` workflow, every push to `call-v2` touching app code |
| Call V2 working-tree guards (14 files: "only allowed files are changed in the working tree") | `tool/run_clean_tree_guards.sh` (temporary clean worktree of HEAD) | Same workflow (a fresh checkout is clean) |
| Test-mode call stability (`test/call_message_stability_test.dart`, tag `test-mode`) | `flutter test --tags test-mode --dart-define=HELPERLY_TEST_MODE=true` | Separate step, `continue-on-error`, see "Known failures" |
| Call V2 focused (`test/call_v2`) | `flutter test test/call_v2` | `Call V2 Flutter Validation` |
| Functions unit tests | `cd connect_functions && node --test test/<area>/*.test.js` | (not in CI yet) |
| Firestore and Storage rules | `firebase --project demo-… emulators:exec --only firestore[,storage] "node --test …"` (Java 17: `JAVA_HOME=/opt/homebrew/opt/openjdk@17`) | (not in CI yet) |

## Why The Guards Fail In A Normal Checkout

The guards assert that the working tree changes only their phase's files.
They use `git diff HEAD` or `git status --untracked-files=all`.

A developer machine always has:
- the local `ios/Podfile.lock` (kept uncommitted by repo rule);
- untracked notes (`.aider*`, `docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md`).

So in a plain `flutter test` run, those 14 tests fail for environment
reasons, not code. They are not disabled. They run where their design
needs them: a clean tree, in CI or through the script.

Evidence (2026-11-01):
- all 14 pass in clean worktrees of `5cc7d4e` (after i18n) and `47b8a8e`
  (before);
- `tool/run_clean_tree_guards.sh` on `bf318dc`: 221/221.

## Known Failures (Tracked, Not Hidden)

`test/call_message_stability_test.dart`, test "50 stability cycles stay
flat and idle".
- Without test mode, both tests throw "startOutgoingCallForTest is
  test-mode only". In test mode one passes; this one expects
  `callInvites.status == "connected"` after `reportRemoteJoined` and gets
  `accepted`.
- Identical before and after the i18n work (`47b8a8e`, `5cc7d4e`). The
  test was last changed on 2026-09-13.
- **Root cause (2026-11-01): an outdated test helper, not a race and not
  a state-machine defect.**
  - The real outgoing path, `startOutgoingCall`
    (`call_session_manager.dart` around line 1820), registers the invite
    with the lifecycle arbiter (`outgoingInviteCreated`, which sets
    `outgoingRinging`).
  - The test-mode helper `startOutgoingCallForTest` (line 1875) predates
    the arbiter and never registers.
  - So in the test the arbiter is not in `outgoingRinging` / `joining`,
    and `markConnected` refuses the transition. The run's diagnostics show
    `lifecycleRegressionSuppressedCount: 2`. `reportRemoteJoined` then
    returns before writing `connected`, and the invite stays `accepted`.
- **Production impact:** none. Real calls go through `startOutgoingCall`,
  and physical calls reached `connected` in October 2026. Billing does not
  read invite status (and paid sessions are off for the beta).
- **Fix (separate call task):** make `startOutgoingCallForTest` register
  with the arbiter like the real path. Test-mode code, but in the call
  manager, so it gets its own task and review.

## CI Toolchain

Workflows pin Flutter 3.35.4 (the local toolchain). Unpinned `stable`
moved to 3.47.9, whose new lint `unawaited_return_in_try_block` failed
`flutter analyze` on `lib/call_v2/real_flow/call_v2_engine_cleanup_coordinator.dart:381`.
CI stopped there, so no tests ran in the last runs. Upgrading Flutter is
a separate, deliberate task (fix that lint in a call task).
