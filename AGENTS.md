# Repository Agent Workflow

These instructions apply to Codex and other coding agents working in this repository.

## Active branch

Use `call-v2` unless `docs/agent-loop/STATE.json` explicitly says otherwise.

## Required startup sequence

Before changing code:

1. Run `git fetch origin` and `git checkout call-v2`.
2. Run `git pull --ff-only origin call-v2`.
3. Read `docs/agent-loop/STATE.json`.
4. Continue only when `status` is `task_ready` or `revision_required`.
5. Confirm local `HEAD` equals `starting_sha` in `STATE.json`. If it does not, stop and report the mismatch without changing files.
6. Read `docs/agent-loop/NEXT_TASK.md` completely.
7. Implement only that task. Do not start a later phase.

## Scope and safety

- Treat `NEXT_TASK.md` as the complete task contract.
- Preserve all accepted architecture and earlier phase contracts.
- Do not deploy unless the active task explicitly authorizes deployment.
- Do not enable production kill switches unless the active task explicitly authorizes it.
- Do not contact production Firebase, Cloud Tasks, APNS, FCM, Agora, Stripe, or other external services during tests unless explicitly authorized.
- Do not modify files outside the task's allowed-file list.
- Never invent production project IDs, regions, URLs, queue names, service accounts, secrets, allowlists, rollout salts, or credentials.
- Keep legacy behavior unchanged unless the active task explicitly requires a legacy change.

## Work sequence

1. Update `docs/agent-loop/STATE.json` to `in_progress` locally before implementation.
2. Implement the active task.
3. Run every validation command required by `NEXT_TASK.md`.
4. Commit the implementation using the exact requested commit message.
5. Record the implementation commit SHA with `git rev-parse HEAD`.
6. Replace `docs/agent-loop/HANDOFF.md` with the exact external-review handoff requested by `NEXT_TASK.md`.
7. Update `docs/agent-loop/STATE.json` with:
   - `status: "ready_for_review"`
   - `code_commit_sha`
   - validation/test results
   - changed files
8. Commit only the handoff/state metadata with:

   `chore(agent-loop): record <phase> review handoff`

9. Set `ending_sha` in `STATE.json` to the metadata commit SHA. Because a commit cannot contain its own SHA, the committed JSON may use `ending_sha: "SELF"`; the handoff must also report both the implementation SHA and metadata SHA. The pushed branch tip is the authoritative ending SHA.
10. Push with `git push origin call-v2`.
11. Stop. Do not begin another phase.

## Handoff requirements

`docs/agent-loop/HANDOFF.md` must contain:

- starting SHA
- implementation/code commit SHA
- pushed branch-tip SHA when known
- exact files created/changed
- implementation summary requested by the active task
- validation commands and results
- total test counts and repeated run results
- Node version
- confirmation of whether dependencies changed
- confirmation that nothing was deployed
- confirmation that no production service was contacted
- remaining risks
- recommendation for the next phase

Do not place raw secrets, tokens, rollout salts, allowlist contents, private user identifiers, provider responses, stack traces, or credentials in the handoff.

## Review loop

After pushing, the human reviewer only needs to tell ChatGPT:

`Review the latest agent-loop handoff.`

ChatGPT will inspect the branch tip, `STATE.json`, `HANDOFF.md`, and the exact GitHub diff. Corrections or the next phase will be written back into `NEXT_TASK.md` and `STATE.json`.