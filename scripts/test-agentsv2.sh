#!/usr/bin/env bash
# test-agentsv2.sh — End-to-end automated verification suite for AgentsV2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/integrations/agentsv2"
INIT_SCRIPT="$PLUGIN_DIR/skills/agentsv2/scripts/init-project.sh"
CHECK_DOCS_SCRIPT="$PLUGIN_DIR/skills/agentsv2/scripts/check-docs-alignment.sh"
GATE_HOOK="$PLUGIN_DIR/scripts/gate-hook.py"
CREATE_SUBAGENT="$SCRIPT_DIR/create-subagent.sh"
INSTALL_SCRIPT="$SCRIPT_DIR/install-agentsv2.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/agentsv2-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

passed=0
pass() { echo "  ok   $1"; passed=$((passed + 1)); }
fail() { echo "  FAIL $1" >&2; exit 1; }

echo "Running AgentsV2 test suite..."

# 1. Validate plugin schema
bash "$SCRIPT_DIR/validate-agentsv2.sh" >/dev/null && pass "validate-agentsv2.sh passes" || fail "validate-agentsv2.sh"

# 2. Mode detection: greenfield vs brownfield-no-docs
proj_green="$TMP/green"
mkdir -p "$proj_green"
mode_g="$(bash "$INIT_SCRIPT" --project "$proj_green" --detect | python3 -c 'import json,sys; print(json.load(sys.stdin)["mode"])')"
[[ "$mode_g" == "greenfield" ]] && pass "detects greenfield project" || fail "expected greenfield, got $mode_g"

proj_brown="$TMP/brown"
mkdir -p "$proj_brown/src"
echo "print('hi')" > "$proj_brown/src/main.py"
mode_b="$(bash "$INIT_SCRIPT" --project "$proj_brown" --detect | python3 -c 'import json,sys; print(json.load(sys.stdin)["mode"])')"
[[ "$mode_b" == "brownfield-no-docs" ]] && pass "detects brownfield-no-docs project" || fail "expected brownfield-no-docs, got $mode_b"

# 3. Dormant gate hook in unmanaged project allows writes
unmanaged="$TMP/unmanaged"
mkdir -p "$unmanaged"
dec_unmanaged="$(printf '{"hookEventName":"PreToolUse","cwd":"%s","toolCall":{"name":"write_to_file","args":{"TargetFile":"%s/src/app.py"}}}' "$unmanaged" "$unmanaged" | python3 "$GATE_HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision"))')"
[[ "$dec_unmanaged" == "allow" ]] && pass "hook stays dormant when .agents/agentsv2-state.json absent" || fail "unmanaged decision=$dec_unmanaged"

# 4. Active project without docs rejects implementation file edits, allows docs edits
bash "$INIT_SCRIPT" --project "$proj_green" --init >/dev/null
dec_deny="$(printf '{"hookEventName":"PreToolUse","cwd":"%s","toolCall":{"name":"write_to_file","args":{"TargetFile":"%s/src/app.py"}}}' "$proj_green" "$proj_green" | python3 "$GATE_HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision"))')"
[[ "$dec_deny" == "deny" ]] && pass "hook denies src/app.py before docs gate completes" || fail "expected deny, got $dec_deny"

dec_doc="$(printf '{"hookEventName":"PreToolUse","cwd":"%s","toolCall":{"name":"write_to_file","args":{"TargetFile":"%s/docs/PRD.md"}}}' "$proj_green" "$proj_green" | python3 "$GATE_HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision"))')"
[[ "$dec_doc" == "allow" ]] && pass "hook allows docs/PRD.md during docs_gate" || fail "expected allow for docs, got $dec_doc"

# 5. check-docs-alignment rejects unfilled templates & passes filled docs
mkdir -p "$proj_green/docs"
cp "$PLUGIN_DIR/skills/agentsv2/resources/templates/PRD.md" "$proj_green/docs/PRD.md"
cp "$PLUGIN_DIR/skills/agentsv2/resources/templates/ARCHITECTURE.md" "$proj_green/docs/ARCHITECTURE.md"
cp "$PLUGIN_DIR/skills/agentsv2/resources/templates/TASKS.md" "$proj_green/docs/TASKS.md"

if bash "$CHECK_DOCS_SCRIPT" --project "$proj_green" >/dev/null 2>&1; then
  fail "check-docs-alignment should reject unfilled template placeholders"
else
  pass "check-docs-alignment rejects unfilled template placeholders"
fi

cat > "$proj_green/docs/PRD.md" <<'EOF'
# Sample Project PRD
- FR-001: Provide a CLI command that greets users deterministically and logs exit status cleanly.
EOF
cat > "$proj_green/docs/ARCHITECTURE.md" <<'EOF'
# Sample Architecture
- Stack: Python 3.12 standard library only.
- Modules: `src/app.py` implements CLI entrypoint; `tests/test_app.py` verifies behavior.
EOF
cat > "$proj_green/docs/TASKS.md" <<'EOF'
# Tasks
- [ ] TASK-001: Implement `src/app.py` and `tests/test_app.py` matching FR-001.
EOF

bash "$CHECK_DOCS_SCRIPT" --project "$proj_green" >/dev/null && pass "check-docs-alignment passes filled docs" || fail "check-docs-alignment failed on valid docs"

# 6. Unlock build phase -> hook now allows src/app.py; Stop blocks until review PASS + docs_synced
bash "$INIT_SCRIPT" --project "$proj_green" --phase build --docs-verified true >/dev/null
dec_allow_code="$(printf '{"hookEventName":"PreToolUse","cwd":"%s","toolCall":{"name":"write_to_file","args":{"TargetFile":"%s/src/app.py"}}}' "$proj_green" "$proj_green" | python3 "$GATE_HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision"))')"
[[ "$dec_allow_code" == "allow" ]] && pass "hook allows src/app.py after docs_verified=true and phase=build" || fail "expected allow, got $dec_allow_code"

stop_block="$(printf '{"hookEventName":"Stop","executionNum":1,"terminationReason":"NO_TOOL_CALL","cwd":"%s"}' "$proj_green" | python3 "$GATE_HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision"))')"
[[ "$stop_block" == "continue" ]] && pass "Stop hook blocks premature termination before review PASS" || fail "expected continue, got $stop_block"

bash "$INIT_SCRIPT" --project "$proj_green" --phase complete --review-status PASS --docs-synced true --workflow-active false >/dev/null
stop_ok="$(printf '{"hookEventName":"Stop","executionNum":1,"terminationReason":"NO_TOOL_CALL","cwd":"%s"}' "$proj_green" | python3 "$GATE_HOOK")"
[[ "$stop_ok" == "{}" ]] && pass "Stop hook allows completion after review PASS & docs_synced=true" || fail "expected {}, got $stop_ok"

# 7. Subagent factory tests (from scratch, from upstream agency agent, invalid tool check)
bash "$CREATE_SUBAGENT" --name "go-perf-reviewer" --description "Read-only Go profiler and concurrency reviewer." --role-preset read-only --scope project --project "$proj_green" >/dev/null
[[ -f "$proj_green/.agents/agents/go-perf-reviewer.md" ]] && pass "create-subagent creates project subagent from scratch" || fail "missing go-perf-reviewer.md"

bash "$CREATE_SUBAGENT" --from-agency "$REPO_ROOT/engineering/engineering-backend-architect.md" --role-preset builder --scope project --project "$proj_green" >/dev/null
[[ -f "$proj_green/.agents/agents/backend-architect.md" ]] && pass "create-subagent converts upstream agency agent" || fail "missing backend-architect.md"

if bash "$CREATE_SUBAGENT" --name "bad-agent" --description "Bad tools test" --tools "nonexistent_tool" --scope project --project "$proj_green" >/dev/null 2>&1; then
  fail "create-subagent should reject unknown Antigravity tool names"
else
  pass "create-subagent rejects unknown Antigravity tool names"
fi

# 8b. Regression test: real Antigravity payload omits hookEventName and cwd
dec_live_unmanaged="$(printf '{"workspacePaths":["%s"],"toolCall":{"name":"write_to_file","args":{"TargetFile":"/tmp/artifact.md"}}}' "$unmanaged" | python3 "$GATE_HOOK" --event PreToolUse | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision"))')"
[[ "$dec_live_unmanaged" == "allow" ]] && pass "hook allows external/unmanaged write when hookEventName omitted" || fail "live unmanaged decision=$dec_live_unmanaged"

bash "$INIT_SCRIPT" --project "$proj_brown" --init >/dev/null
dec_live_deny="$(printf '{"workspacePaths":["%s"],"toolCall":{"name":"write_to_file","args":{"TargetFile":"%s/src/main.py"}}}' "$proj_brown" "$proj_brown" | python3 "$GATE_HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision"))')"
[[ "$dec_live_deny" == "deny" ]] && pass "hook infers PreToolUse and denies brownfield write without hookEventName" || fail "live brownfield deny decision=$dec_live_deny"

# 9. Sandbox install test
sandbox_home="$TMP/home"
mkdir -p "$sandbox_home"
HOME="$sandbox_home" bash "$INSTALL_SCRIPT" --global >/dev/null
[[ -f "$sandbox_home/.gemini/config/plugins/agentsv2/plugin.json" ]] && pass "install-agentsv2.sh installs plugin into sandbox HOME" || fail "sandbox plugin install missing"

echo "PASS: All $passed AgentsV2 tests succeeded."
