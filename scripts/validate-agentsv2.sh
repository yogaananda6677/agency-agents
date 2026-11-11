#!/usr/bin/env bash
# validate-agentsv2.sh — Strict schema & safety validator for integrations/agentsv2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/integrations/agentsv2"

python3 - "$PLUGIN_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("ERROR: PyYAML is required for validate-agentsv2.sh") from exc

plugin = Path(sys.argv[1])
errors: list[str] = []

def err(msg: str) -> None:
    errors.append(msg)

# 1. Check LF line endings across all text files
for path in sorted(plugin.rglob("*")):
    if path.is_file() and path.suffix in (".md", ".json", ".py", ".sh", ".svg"):
        data = path.read_bytes()
        if b"\r" in data:
            err(f"CRLF detected: {path.relative_to(plugin)}")

# 2. Validate plugin.json
manifest_path = plugin / "plugin.json"
if not manifest_path.is_file():
    err("Missing plugin.json")
else:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        name = manifest.get("name", "")
        if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name):
            err(f"Invalid plugin.json name: {name!r}")
        for req in ("displayName", "description", "version", "logo", "author"):
            if not manifest.get(req):
                err(f"plugin.json missing required field '{req}'")
        logo = manifest.get("logo", "")
        if logo and not (plugin / logo).is_file():
            err(f"plugin.json logo missing on disk: {logo}")
        prompts = manifest.get("suggestedPrompts", [])
        if len(prompts) > 3:
            err(f"plugin.json suggestedPrompts exceeds maxItems=3 ({len(prompts)})")
    except json.JSONDecodeError as e:
        err(f"Invalid plugin.json JSON: {e}")

# 3. Validate hooks.json
hooks_path = plugin / "hooks.json"
if hooks_path.is_file():
    try:
        hooks = json.loads(hooks_path.read_text(encoding="utf-8"))
        for group_name, spec in hooks.items():
            if not isinstance(spec, dict):
                err(f"hooks.json '{group_name}' must be an object")
                continue
            for ev in ("PreToolUse", "PostToolUse"):
                if ev in spec:
                    if not isinstance(spec[ev], list):
                        err(f"hooks.json {group_name}.{ev} must be an array")
                    for entry in spec[ev]:
                        if "matcher" not in entry or not isinstance(entry.get("hooks"), list):
                            err(f"hooks.json {group_name}.{ev} entry must have 'matcher' and 'hooks' array")
                        for h in entry.get("hooks", []):
                            cmd = h.get("command", "")
                            if "${PLUGIN_ROOT}" in cmd:
                                err(f"hooks.json command must use relative path, not ${{PLUGIN_ROOT}}: {cmd}")
            for ev in ("SessionStart", "PreInvocation", "PostInvocation", "Stop"):
                if ev in spec:
                    if not isinstance(spec[ev], list):
                        err(f"hooks.json {group_name}.{ev} must be a flat array")
                    for entry in spec[ev]:
                        if "hooks" in entry:
                            err(f"hooks.json {group_name}.{ev} must be flat handlers without 'hooks' wrapper")
                        if not entry.get("command"):
                            err(f"hooks.json {group_name}.{ev} handler missing 'command'")
    except json.JSONDecodeError as e:
        err(f"Invalid hooks.json: {e}")

def parse_frontmatter(md_path: Path) -> tuple[dict, str]:
    text = md_path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError("missing opening ---")
    parts = text.split("\n---\n", 1)
    if len(parts) != 2:
        raise ValueError("missing closing ---")
    fm = yaml.safe_load(parts[0][4:])
    if not isinstance(fm, dict):
        raise ValueError("frontmatter is not a YAML mapping")
    return fm, parts[1]

# 4. Validate skills
skills_dir = plugin / "skills"
if not skills_dir.is_dir():
    err("Missing skills/ directory")
else:
    for skill_folder in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
        skill_md = skill_folder / "SKILL.md"
        if not skill_md.is_file():
            err(f"Missing SKILL.md in {skill_folder.name}")
            continue
        try:
            fm, _ = parse_frontmatter(skill_md)
        except Exception as e:
            err(f"skills/{skill_folder.name}/SKILL.md invalid frontmatter: {e}")
            continue
        sname = fm.get("name", "")
        sdesc = fm.get("description", "")
        if sname != skill_folder.name:
            err(f"skills/{skill_folder.name}/SKILL.md name {sname!r} != folder name {skill_folder.name!r}")
        if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", sname):
            err(f"Skill name not kebab-case: {sname!r}")
        if not isinstance(sdesc, str) or not (1 <= len(sdesc.strip()) <= 1024):
            err(f"skills/{skill_folder.name}/SKILL.md description missing or out of 1..1024 chars")

# 5. Validate custom subagents
VALID_TOOLS = {
    "view_file", "list_dir", "grep_search", "find_by_name", "search_web",
    "read_url_content", "write_to_file", "replace_file_content", "run_command",
    "manage_task", "send_message", "invoke_subagent", "define_subagent",
    "manage_subagents", "schedule", "ask_question", "generate_image",
    "call_mcp_tool", "list_resources", "read_resource",
}
READ_ONLY_AGENTS = {"agentsv2-code-reviewer", "agentsv2-security-auditor"}
FORBIDDEN_READ_ONLY_TOOLS = {"write_to_file", "replace_file_content", "run_command"}

agents_dir = plugin / "agents"
if not agents_dir.is_dir():
    err("Missing agents/ directory")
else:
    for agent_md in sorted(agents_dir.glob("*.md")):
        try:
            fm, _ = parse_frontmatter(agent_md)
        except Exception as e:
            err(f"agents/{agent_md.name} invalid frontmatter: {e}")
            continue
        aname = fm.get("name", "")
        if aname != agent_md.stem:
            err(f"agents/{agent_md.name} name {aname!r} != stem {agent_md.stem!r}")
        if not fm.get("description"):
            err(f"agents/{agent_md.name} missing description")
        tools = fm.get("tools", [])
        if not isinstance(tools, list) or not tools:
            err(f"agents/{agent_md.name} tools must be a non-empty list")
        else:
            bad_tools = [t for t in tools if t not in VALID_TOOLS]
            if bad_tools:
                err(f"agents/{agent_md.name} has unknown tool(s): {bad_tools}")
            if aname in READ_ONLY_AGENTS:
                violated = [t for t in tools if t in FORBIDDEN_READ_ONLY_TOOLS]
                if violated:
                    err(f"Read-only agent {aname} must not include tools: {violated}")
        if fm.get("model") not in ("inherit", "flash_lite", "flash", "pro"):
            err(f"agents/{agent_md.name} invalid model: {fm.get('model')!r}")
        if fm.get("commandExecutionPolicy") not in ("auto", "sandbox", "off", "eager"):
            err(f"agents/{agent_md.name} invalid commandExecutionPolicy: {fm.get('commandExecutionPolicy')!r}")

# 6. Validate rules
rules_dir = plugin / "rules"
if rules_dir.is_dir():
    for rule_md in sorted(rules_dir.glob("*.md")):
        if rule_md.name in ("AGENTS.md", "GEMINI.md"):
            continue
        try:
            fm, _ = parse_frontmatter(rule_md)
        except Exception as e:
            err(f"rules/{rule_md.name} invalid frontmatter: {e}")
            continue
        trig = fm.get("trigger")
        if trig not in ("always_on", "model_decision", "glob", "manual"):
            err(f"rules/{rule_md.name} invalid trigger: {trig!r}")
        if trig == "glob" and not isinstance(fm.get("globs"), str):
            err(f"rules/{rule_md.name} globs must be a comma-separated string, not a list")

if errors:
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    raise SystemExit(1)

print(f"[OK] Validated AgentsV2 plugin at {plugin}")
PY
