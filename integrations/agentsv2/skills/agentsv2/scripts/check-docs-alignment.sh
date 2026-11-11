#!/usr/bin/env bash
# check-docs-alignment.sh — Validate Phase 1 canonical docs before allowing code phase.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  check-docs-alignment.sh [--project <dir>] [--require-all-tasks-done] [--help]
EOF
}

PROJECT="."
REQUIRE_DONE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:?missing path}"; shift 2 ;;
    --require-all-tasks-done) REQUIRE_DONE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

PROJECT_ABS="$(cd "$PROJECT" && pwd)"

python3 - "$PROJECT_ABS" "$REQUIRE_DONE" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
require_done = sys.argv[2] == "true"

required = ["docs/PRD.md", "docs/ARCHITECTURE.md", "docs/TASKS.md"]
state_file = root / ".agents" / "agentsv2-state.json"
if state_file.is_file():
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
        if isinstance(state.get("required_docs"), list) and state["required_docs"]:
            required = [str(x) for x in state["required_docs"]]
    except (OSError, json.JSONDecodeError):
        pass

errors: list[str] = []
warnings: list[str] = []

for rel in required:
    p = root / rel
    if not p.is_file():
        errors.append(f"MISSING: {rel}")
        continue
    text = p.read_text(encoding="utf-8", errors="ignore").strip()
    if len(text) < 80:
        errors.append(f"TOO_SHORT_OR_STUB: {rel} ({len(text)} chars)")
        continue
    if "<Project Name>" in text or "<e.g.," in text or "<command>" in text:
        errors.append(f"UNFILLED_TEMPLATE_PLACEHOLDERS: {rel}")

tasks_path = root / "docs" / "TASKS.md"
done_count = 0
open_count = 0
if tasks_path.is_file():
    ttext = tasks_path.read_text(encoding="utf-8", errors="ignore")
    done_count = len(re.findall(r"(?m)^(?:#{2,4}|[-*])\s*\[x\]", ttext, re.IGNORECASE))
    open_count = len(re.findall(r"(?m)^(?:#{2,4}|[-*])\s*\[ \]", ttext))
    if done_count + open_count == 0:
        errors.append("NO_CHECKABLE_TASKS: docs/TASKS.md must contain [ ] or [x] task entries")
    if require_done and open_count > 0:
        errors.append(f"OPEN_TASKS_REMAINING: {open_count} unchecked task(s) in docs/TASKS.md")

print(f"Project: {root}")
print(f"Tasks: {done_count} completed, {open_count} open")
for w in warnings:
    print(f"WARN: {w}")
for e in errors:
    print(f"REJECTED: {e}")

if errors:
    print("\nPhase 1 Documentation Gate FAILED. Create/complete required docs before implementation.")
    sys.exit(1)

print("PASS: Phase 1 documentation gate checks satisfied.")
PY
