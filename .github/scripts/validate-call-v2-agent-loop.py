#!/usr/bin/env python3
"""Fail-closed preflight for the Helperly Call V2 guarded agent loop.

This script is intentionally network-free. It validates that STATE.json,
NEXT_TASK.md, the trigger contract, and the current Git history agree before
any builder or expensive validation work starts.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE_PATH = ROOT / "docs/agent-loop/STATE.json"
DEFAULT_TASK_PATH = "docs/agent-loop/NEXT_TASK.md"
TRIGGER_PATH = ROOT / ".github/agent-loop/phase3a-retry.txt"
WORKFLOW_PATH = ROOT / ".github/workflows/call-v2-phase3a-retry.yml"
ALLOWED_STATUSES = {"task_ready", "revision_required"}
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def fail(message: str) -> None:
    print(f"agent-loop preflight failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        fail(f"git {' '.join(args)} failed")
    return result.stdout.strip()


def require_ancestor(label: str, sha: object, head: str) -> str:
    if not isinstance(sha, str) or not SHA_RE.fullmatch(sha):
        fail(f"{label} is not a full commit SHA")
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", sha, head],
        cwd=ROOT,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        fail(f"{label} is not an ancestor of HEAD")
    return sha


def read_trigger() -> dict[str, str]:
    if not TRIGGER_PATH.exists():
        return {}
    values: dict[str, str] = {}
    for raw_line in TRIGGER_PATH.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def main() -> None:
    if not STATE_PATH.is_file():
        fail("STATE.json is missing")
    if not WORKFLOW_PATH.is_file():
        fail("guarded workflow is missing")

    try:
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"STATE.json is invalid: {exc}")

    if state.get("branch") != "call-v2":
        fail("STATE branch must be call-v2")

    phase = state.get("phase")
    if not isinstance(phase, str) or not phase.strip():
        fail("STATE phase is empty")
    phase = phase.strip()

    status = state.get("status")
    if status not in ALLOWED_STATUSES:
        fail(f"STATE status {status!r} is not runnable")

    task_relative = state.get("task_file")
    if task_relative != DEFAULT_TASK_PATH:
        fail(f"STATE task_file must be {DEFAULT_TASK_PATH}")
    task_path = ROOT / task_relative
    if not task_path.is_file() or not task_path.read_text(encoding="utf-8").strip():
        fail("authoritative NEXT_TASK.md is missing or empty")

    task_text = task_path.read_text(encoding="utf-8")
    if f"Phase {phase}" not in task_text:
        fail(f"NEXT_TASK.md does not identify Phase {phase}")

    head = git("rev-parse", "HEAD")
    require_ancestor("starting_sha", state.get("starting_sha"), head)
    accepted_checkpoint = require_ancestor(
        "accepted_checkpoint_sha", state.get("accepted_checkpoint_sha"), head
    )

    task_bytes = task_path.read_bytes()
    task_sha256 = hashlib.sha256(task_bytes).hexdigest()
    task_blob = git("hash-object", task_relative)

    trigger = read_trigger()
    trigger_phase = trigger.get("phase")
    if trigger_phase and trigger_phase != phase:
        fail(f"trigger phase {trigger_phase!r} does not match STATE phase {phase!r}")
    trigger_task = trigger.get("prompt_task")
    if trigger_task and trigger_task != task_relative:
        fail("trigger prompt_task does not match STATE task_file")
    trigger_blob = trigger.get("task_blob")
    if trigger_blob and trigger_blob != task_blob:
        fail("trigger task_blob is stale")
    trigger_checkpoint = trigger.get("accepted_checkpoint")
    if trigger_checkpoint and trigger_checkpoint != accepted_checkpoint:
        fail("trigger accepted_checkpoint is stale")
    trigger_baseline = trigger.get("baseline_head")
    if trigger_baseline:
        require_ancestor("trigger baseline_head", trigger_baseline, head)

    workflow_text = WORKFLOW_PATH.read_text(encoding="utf-8")
    if re.search(r'\$phase"\s*!=\s*"[0-9A-Za-z_-]+"', workflow_text):
        fail("workflow contains a hard-coded phase lock")
    if "docs/agent-loop/NEXT_TASK.md is the sole authoritative" not in workflow_text:
        fail("workflow does not preserve NEXT_TASK.md as sole authority")

    print(
        "agent-loop preflight passed: "
        f"phase={phase} status={status} head={head} "
        f"task_sha256={task_sha256} task_blob={task_blob}"
    )


if __name__ == "__main__":
    main()
