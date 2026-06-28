# Repository Agent Workflow

Use branch `call-v2` unless `docs/agent-loop/STATE.json` says otherwise.

Before editing:
1. Pull `origin/call-v2` with fast-forward only.
2. Read `docs/agent-loop/STATE.json`.
3. Continue only for `task_ready` or `revision_required`.
4. Confirm `starting_sha` is an ancestor of `HEAD`.
5. Before implementation, newer paths may only be `AGENTS.md` and `docs/agent-loop/**`.
6. Read `docs/agent-loop/NEXT_TASK.md` and implement only that task.

During work:
- Stay inside the task's allowed files.
- Preserve earlier accepted behavior.
- Do not deploy or enable live settings unless the task explicitly says so.
- Run every validation command in the task.

After work:
1. Commit the implementation with the requested message.
2. Replace `docs/agent-loop/HANDOFF.md` with the requested review summary.
3. Update `STATE.json` to `ready_for_review` with the implementation SHA, changed files, and test results.
4. Commit handoff/state as `chore(agent-loop): record <phase> review handoff`.
5. `ending_sha` may be `SELF`; the pushed branch tip is authoritative.
6. Push `origin/call-v2` and stop.

After push, the user can tell ChatGPT: `Review the latest agent-loop handoff.`