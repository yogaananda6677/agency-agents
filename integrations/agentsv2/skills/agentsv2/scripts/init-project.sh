#!/usr/bin/env bash
# init-project.sh — Detect Greenfield vs Brownfield mode and manage .agents/agentsv2-state.json.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  init-project.sh [--project <dir>] [--detect] [--init] [--reset]
                  [--phase <intake|docs_gate|build|review|docs_sync|complete>]
                  [--docs-verified <true|false>]
                  [--review-status <PENDING|PASS|NEEDS_WORK>]
                  [--docs-synced <true|false>]
                  [--workflow-active <true|false>]
                  [--pause <true|false>]
                  [--retry-task <task_id>]
                  [--reset-retries <task_id>]
                  [--help]
EOF
}

PROJECT="."
DO_DETECT=false
DO_INIT=false
DO_RESET=false
PHASE=""
DOCS_VERIFIED=""
REVIEW_STATUS=""
DOCS_SYNCED=""
WORKFLOW_ACTIVE=""
PAUSE=""
RETRY_TASK=""
RESET_RETRIES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:?missing path}"; shift 2 ;;
    --detect) DO_DETECT=true; shift ;;
    --init) DO_INIT=true; shift ;;
    --reset) DO_RESET=true; shift ;;
    --phase) PHASE="${2:?missing phase}"; shift 2 ;;
    --docs-verified) DOCS_VERIFIED="${2:?missing bool}"; shift 2 ;;
    --review-status) REVIEW_STATUS="${2:?missing status}"; shift 2 ;;
    --docs-synced) DOCS_SYNCED="${2:?missing bool}"; shift 2 ;;
    --workflow-active) WORKFLOW_ACTIVE="${2:?missing bool}"; shift 2 ;;
    --pause) PAUSE="${2:?missing bool}"; shift 2 ;;
    --retry-task) RETRY_TASK="${2:?missing task id}"; shift 2 ;;
    --reset-retries) RESET_RETRIES="${2:?missing task id}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

PROJECT_ABS="$(cd "$PROJECT" && pwd)"

python3 - "$PROJECT_ABS" "$DO_DETECT" "$DO_INIT" "$DO_RESET" \
  "$PHASE" "$DOCS_VERIFIED" "$REVIEW_STATUS" "$DOCS_SYNCED" \
  "$WORKFLOW_ACTIVE" "$PAUSE" "$RETRY_TASK" "$RESET_RETRIES" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

(
    project_str,
    do_detect_s,
    do_init_s,
    do_reset_s,
    phase,
    docs_verified_s,
    review_status,
    docs_synced_s,
    workflow_active_s,
    pause_s,
    retry_task,
    reset_retries,
) = sys.argv[1:]

root = Path(project_str)
state_dir = root / ".agents"
state_path = state_dir / "agentsv2-state.json"
required_docs = ["docs/PRD.md", "docs/ARCHITECTURE.md", "docs/TASKS.md"]

def parse_bool(val: str) -> bool | None:
    if not val:
        return None
    low = val.strip().lower()
    if low in ("true", "1", "yes"):
        return True
    if low in ("false", "0", "no"):
        return False
    raise SystemExit(f"Invalid boolean value: {val}")

def scan_repo() -> dict:
    manifests = [
        "package.json", "pyproject.toml", "requirements.txt", "go.mod",
        "Cargo.toml", "pubspec.yaml", "pom.xml", "build.gradle", "Makefile",
    ]
    found_manifests = [m for m in manifests if (root / m).exists()]
    code_dirs = [d for d in ("src", "lib", "app", "cmd", "pkg", "backend", "frontend", "server", "client") if (root / d).is_dir()]

    top_files = []
    for item in sorted(root.iterdir()):
        if item.name.startswith("."):
            continue
        if item.is_file() and item.suffix in (".py", ".ts", ".tsx", ".js", ".jsx", ".go", ".rs", ".dart", ".java", ".kt", ".rb", ".php", ".c", ".cpp"):
            top_files.append(item.name)

    existing_docs = [d for d in required_docs if (root / d).is_file() and (root / d).stat().st_size >= 40]
    missing_docs = [d for d in required_docs if d not in existing_docs]
    has_code = bool(found_manifests or code_dirs or top_files)

    if state_path.is_file():
        mode = "resume-active"
    elif not has_code:
        mode = "greenfield"
    elif missing_docs:
        mode = "brownfield-no-docs"
    else:
        mode = "brownfield-with-docs"

    return {
        "project_root": str(root),
        "mode": mode,
        "has_existing_code": has_code,
        "manifests": found_manifests,
        "code_dirs": code_dirs,
        "existing_docs": existing_docs,
        "missing_docs": missing_docs,
        "state_exists": state_path.is_file(),
    }

info = scan_repo()

if do_detect_s == "true":
    print(json.dumps(info, indent=2))

should_write = any([
    do_init_s == "true",
    do_reset_s == "true",
    bool(phase),
    bool(docs_verified_s),
    bool(review_status),
    bool(docs_synced_s),
    bool(workflow_active_s),
    bool(pause_s),
    bool(retry_task),
    bool(reset_retries),
])

if should_write:
    if state_path.is_file() and do_reset_s != "true":
        state = json.loads(state_path.read_text(encoding="utf-8"))
    else:
        state = {
            "schema_version": "1.0.0",
            "enabled": True,
            "mode": info["mode"] if info["mode"] != "resume-active" else "brownfield-no-docs",
            "phase": "docs_gate",
            "workflow_active": True,
            "paused_waiting_for_user": False,
            "docs_verified": False,
            "review_status": "PENDING",
            "docs_synced": False,
            "max_task_retries": 3,
            "required_docs": required_docs,
            "task_retries": {},
            "updated_at": "",
        }

    if phase:
        valid_phases = {"intake", "docs_gate", "build", "review", "docs_sync", "complete"}
        if phase not in valid_phases:
            raise SystemExit(f"Invalid phase '{phase}'. Expected one of: {sorted(valid_phases)}")
        state["phase"] = phase

    bv = parse_bool(docs_verified_s)
    if bv is not None:
        state["docs_verified"] = bv

    if review_status:
        valid_rev = {"PENDING", "PASS", "NEEDS_WORK"}
        if review_status not in valid_rev:
            raise SystemExit(f"Invalid review status '{review_status}'. Expected one of: {sorted(valid_rev)}")
        state["review_status"] = review_status

    bs = parse_bool(docs_synced_s)
    if bs is not None:
        state["docs_synced"] = bs

    bw = parse_bool(workflow_active_s)
    if bw is not None:
        state["workflow_active"] = bw

    bp = parse_bool(pause_s)
    if bp is not None:
        state["paused_waiting_for_user"] = bp

    if retry_task:
        retries = state.setdefault("task_retries", {})
        retries[retry_task] = int(retries.get(retry_task, 0)) + 1

    if reset_retries:
        retries = state.setdefault("task_retries", {})
        retries.pop(reset_retries, None)

    state["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state_dir.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    if do_detect_s != "true":
        print(json.dumps(state, indent=2))
PY
