# Testing

## Where Each Kind Of Test Runs

| Tests | Local | CI |
|---|---|---|
| Flutter unit and widget tests (`test/`) | `flutter test --exclude-tags test-mode` | `App Flutter Tests` workflow, every push to `call-v2` touching app code |
| Call V2 working-tree guards (14 files: "only allowed files are changed in the working tree") | `tool/run_clean_tree_guards.sh` (temporary clean worktree of HEAD) | Same workflow (a fresh checkout is clean) |
| Test-mode call stability (`test/call_message_stability_test.dart`, tag `test-mode`) | `flutter test test/call_message_stability_test.dart --dart-define=HELPERLY_TEST_MODE=true` | Separate blocking CI step |
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

## Test-Mode Call Stability

Run the tagged call stability suite separately with
`flutter test --tags test-mode --dart-define=HELPERLY_TEST_MODE=true`.
Its fake Firestore setup injects an unavailable callable transport so call
transitions exercise the local Firestore fallback. The test-only outgoing
helper registers its invite with the lifecycle arbiter, matching the real
outgoing path without changing production call behavior.

## CI Toolchain

Workflows pin Flutter 3.35.4 (the local toolchain). Unpinned `stable`
moved to 3.47.9, whose new lint `unawaited_return_in_try_block` failed
`flutter analyze` on `lib/call_v2/real_flow/call_v2_engine_cleanup_coordinator.dart:381`.
CI stopped there, so no tests ran in the last runs. Upgrading Flutter is
a separate, deliberate task (fix that lint in a call task).
