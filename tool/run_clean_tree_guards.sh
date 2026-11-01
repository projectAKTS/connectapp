#!/bin/bash
# Runs the Call V2 working-tree guard tests the way CI does: in a temporary
# clean worktree of HEAD. Local lockfile edits and untracked notes make them
# fail in the normal checkout (see docs/TESTING.md).
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
WT=$(mktemp -d)/clean
git -C "$ROOT" worktree add -q --detach "$WT" HEAD
trap 'git -C "$ROOT" worktree remove --force "$WT"' EXIT
cd "$WT"
flutter pub get >/dev/null
GUARDS=$(grep -rl "only allowed files are changed in the working tree" test | sort)
# shellcheck disable=SC2086
flutter test $GUARDS
