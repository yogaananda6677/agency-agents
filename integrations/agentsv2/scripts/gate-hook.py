#!/usr/bin/env python3
"""
Deterministic Antigravity lifecycle gate hook for AgentsV2.

Behavior:
- Dormant when no `.agents/agentsv2-state.json` exists for the active project
  (returns allow / {} immediately so unrelated projects are unaffected).
- When `.agents/agentsv2-state.json` is active:
  1. PreToolUse (write/edit tools): Blocks creating or editing implementation
     files if Phase 1 documentation prerequisites (`docs_verified` == true and
     required docs present/non-empty) are not satisfied. Always permits editing
     documentation, `.agents/**`, and root markdown files.
  2. Stop: Prevents premature completion during an active workflow if review
     has not passed (`review_status != "PASS"`) or docs are not synced, unless
     paused for user input or safety retry limits are reached.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

DEFAULT_REQUIRED_DOCS = [
    "docs/PRD.md",
    "docs/ARCHITECTURE.md",
    "docs/TASKS.md",
]

ALLOWED_PRE_GATE_EXACT = {
    "README.md",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "PRD.md",
    "SPEC.md",
    "ARCHITECTURE.md",
    "TASKS.md",
    ".gitignore",
    ".gitattributes",
}

ALLOWED_PRE_GATE_PREFIXES = (
    ".agents/",
    ".agent/",
    "docs/",
    "doc/",
)


def find_project_root(payload: dict[str, Any], target_file: str) -> Path | None:
    """Locate the nearest directory containing `.agents/agentsv2-state.json`."""
    candidates: list[Path] = []
    if target_file:
        p = Path(target_file).expanduser()
        if not p.is_absolute() and payload.get("cwd"):
            p = Path(payload["cwd"]) / p
        try:
            resolved = p.resolve()
        except OSError:
            resolved = p
        candidates.extend([resolved.parent, *resolved.parents])

    if payload.get("cwd"):
        cwd = Path(str(payload["cwd"])).expanduser()
        candidates.extend([cwd, *cwd.parents])

    for ws in payload.get("workspacePaths") or []:
        ws_path = Path(str(ws)).expanduser()
        candidates.extend([ws_path, *ws_path.parents])

    seen: set[Path] = set()
    for d in candidates:
        if d in seen:
            continue
        seen.add(d)
        if (d / ".agents" / "agentsv2-state.json").is_file():
            return d
    return None


def is_doc_or_meta_path(rel_path: str) -> bool:
    """Return True if path is documentation, .agents metadata, or root markdown."""
    norm = rel_path.replace("\\", "/").lstrip("./")
    if norm in ALLOWED_PRE_GATE_EXACT:
        return True
    if any(norm.startswith(prefix) for prefix in ALLOWED_PRE_GATE_PREFIXES):
        return True
    if "/" not in norm and norm.lower().endswith(".md"):
        return True
    return False


def missing_docs(root: Path, state: dict[str, Any]) -> list[str]:
    """Return required doc paths that are missing or empty."""
    req = state.get("required_docs")
    if not isinstance(req, list) or not req:
        req = DEFAULT_REQUIRED_DOCS
    missing: list[str] = []
    for rel in req:
        doc_path = root / str(rel)
        if not doc_path.is_file():
            missing.append(f"{rel} (missing)")
            continue
        try:
            content = doc_path.read_text(encoding="utf-8", errors="ignore").strip()
        except OSError:
            missing.append(f"{rel} (unreadable)")
            continue
        if len(content) < 40:
            missing.append(f"{rel} (empty/stub)")
    return missing


def handle_pre_tool_use(payload: dict[str, Any]) -> dict[str, Any]:
    """Enforce Phase 1 doc-first gate before writing non-doc files."""
    tool_call = payload.get("toolCall") or {}
    args = tool_call.get("args") or {}
    target_file = str(args.get("TargetFile") or args.get("target_file") or "")
    if not target_file:
        return {"decision": "allow"}

    root = find_project_root(payload, target_file)
    if root is None:
        return {"decision": "allow"}

    state_file = root / ".agents" / "agentsv2-state.json"
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"decision": "allow"}

    if state.get("enabled", True) is False:
        return {"decision": "allow"}

    # Allow files outside the project root (e.g., Antigravity brain/scratch artifacts)
    target_path = Path(target_file).expanduser()
    if not target_path.is_absolute():
        base_dir = payload.get("cwd") or (payload.get("workspacePaths") or [""])[0]
        if base_dir:
            target_path = Path(str(base_dir)) / target_path
    try:
        rel = target_path.resolve().relative_to(root.resolve())
    except ValueError:
        return {"decision": "allow"}

    rel_posix = rel.as_posix()
    if is_doc_or_meta_path(rel_posix):
        return {"decision": "allow"}

    phase = str(state.get("phase") or "intake")
    docs_verified = bool(state.get("docs_verified", False))
    missing = missing_docs(root, state)

    if phase in ("intake", "docs_gate") or not docs_verified or missing:
        reasons: list[str] = []
        if phase in ("intake", "docs_gate"):
            reasons.append(f"current phase is '{phase}' (must reach 'build' or later)")
        if not docs_verified:
            reasons.append("docs_verified is false in .agents/agentsv2-state.json")
        if missing:
            reasons.append("incomplete docs: " + ", ".join(missing))

        return {
            "decision": "deny",
            "reason": (
                f"AGENTSv2 PHASE-GATE REJECTION: Refused edit to '{rel_posix}'. "
                + "; ".join(reasons)
                + ". Complete Phase 1 (use /agentsv2-doc-gate or create/verify "
                "docs/PRD.md, docs/ARCHITECTURE.md, docs/TASKS.md and mark "
                "docs_verified=true, phase='build') before editing implementation files."
            ),
        }

    return {"decision": "allow"}


def handle_stop(payload: dict[str, Any]) -> dict[str, Any]:
    """Block premature termination if an active workflow missed review or docs sync."""
    termination_reason = str(payload.get("terminationReason") or "")
    if termination_reason and termination_reason != "NO_TOOL_CALL":
        return {}

    execution_num = int(payload.get("executionNum") or 1)
    if execution_num >= 3:
        return {}

    root = find_project_root(payload, "")
    if root is None:
        return {}

    state_file = root / ".agents" / "agentsv2-state.json"
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}

    if state.get("enabled", True) is False:
        return {}
    if not state.get("workflow_active", False):
        return {}
    if state.get("paused_waiting_for_user", False):
        return {}

    phase = str(state.get("phase") or "intake")
    review_status = str(state.get("review_status") or "PENDING")
    docs_synced = bool(state.get("docs_synced", False))

    if phase in ("build", "review", "docs_sync") and (
        review_status != "PASS" or not docs_synced
    ):
        return {
            "decision": "continue",
            "reason": (
                "AGENTSv2 LIFECYCLE GATE: Workflow is still active with "
                f"phase='{phase}', review_status='{review_status}', "
                f"docs_synced={docs_synced}. Run /agentsv2-review and "
                "/agentsv2-docs-sync until review_status='PASS' and "
                "docs_synced=true (and set workflow_active=false), or set "
                "paused_waiting_for_user=true if awaiting user input."
            ),
        }

    return {}


def parse_cli_event(argv: list[str]) -> str:
    """Read optional --event <name> argument without pulling heavy parsers."""
    for idx, arg in enumerate(argv):
        if arg == "--event" and idx + 1 < len(argv):
            return argv[idx + 1]
        if arg.startswith("--event="):
            return arg.split("=", 1)[1]
    return ""


def infer_event(cli_event: str, payload: dict[str, Any]) -> str:
    """Resolve hook event name from CLI flag, payload hookEventName, or shape."""
    if cli_event:
        return cli_event
    if payload.get("hookEventName"):
        return str(payload["hookEventName"])
    if "toolCall" in payload:
        return "PreToolUse"
    if "terminationReason" in payload or "executionNum" in payload:
        return "Stop"
    return ""


def main() -> int:
    cli_event = parse_cli_event(sys.argv[1:])
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        print('{"decision": "allow"}' if cli_event == "PreToolUse" else "{}")
        return 0

    event = infer_event(cli_event, payload)
    if event == "PreToolUse":
        result = handle_pre_tool_use(payload)
    elif event == "Stop":
        result = handle_stop(payload)
    else:
        result = {}

    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
