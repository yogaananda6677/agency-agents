#!/usr/bin/env bash
# create-subagent.sh — Generate or convert validated Antigravity custom subagent .md files.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-subagent.sh [options]

Options:
  --name <kebab-case>           Subagent identifier (required unless --from-agency is set)
  --description <text>          Delegation description (required unless --from-agency is set)
  --from-agency <path>          Convert an existing agency-agents .md file into an Antigravity subagent
  --role-preset <preset>        read-only | verifier | builder | orchestrator (default: builder)
  --tools <comma,list>          Explicit Antigravity tool allowlist (overrides --role-preset)
  --scope <project|global>      Write to <project>/.agents/agents/ or ~/.gemini/config/agents/ (default: project)
  --project <dir>               Target project root when --scope=project (default: .)
  --model <tier>                inherit | flash | pro (default: inherit)
  --main-agent <true|false>     Allow selection as primary agent (default: false)
  --policy <mode>               auto | sandbox | off | eager (default: auto)
  --prompt <text>               Custom English system prompt body (when creating from scratch)
  --overwrite                   Overwrite existing target file
  --help                        Show this help
EOF
}

NAME=""
DESCRIPTION=""
FROM_AGENCY=""
ROLE_PRESET="builder"
TOOLS_CSV=""
SCOPE="project"
PROJECT="."
MODEL="inherit"
MAIN_AGENT="false"
POLICY="auto"
PROMPT_BODY=""
OVERWRITE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:?missing name}"; shift 2 ;;
    --description) DESCRIPTION="${2:?missing description}"; shift 2 ;;
    --from-agency) FROM_AGENCY="${2:?missing path}"; shift 2 ;;
    --role-preset) ROLE_PRESET="${2:?missing preset}"; shift 2 ;;
    --tools) TOOLS_CSV="${2:?missing tools}"; shift 2 ;;
    --scope) SCOPE="${2:?missing scope}"; shift 2 ;;
    --project) PROJECT="${2:?missing project}"; shift 2 ;;
    --model) MODEL="${2:?missing model}"; shift 2 ;;
    --main-agent) MAIN_AGENT="${2:?missing bool}"; shift 2 ;;
    --policy) POLICY="${2:?missing policy}"; shift 2 ;;
    --prompt) PROMPT_BODY="${2:?missing prompt}"; shift 2 ;;
    --overwrite) OVERWRITE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

python3 - "$NAME" "$DESCRIPTION" "$FROM_AGENCY" "$ROLE_PRESET" "$TOOLS_CSV" \
  "$SCOPE" "$PROJECT" "$MODEL" "$MAIN_AGENT" "$POLICY" "$PROMPT_BODY" "$OVERWRITE" <<'PY'
import os
import re
import sys
from pathlib import Path

(
    name,
    description,
    from_agency,
    role_preset,
    tools_csv,
    scope,
    project,
    model,
    main_agent,
    policy,
    prompt_body,
    overwrite_s,
) = sys.argv[1:]

overwrite = overwrite_s == "true"

VALID_TOOLS = {
    "view_file",
    "list_dir",
    "grep_search",
    "find_by_name",
    "search_web",
    "read_url_content",
    "write_to_file",
    "replace_file_content",
    "run_command",
    "manage_task",
    "send_message",
    "invoke_subagent",
    "define_subagent",
    "manage_subagents",
    "schedule",
    "ask_question",
    "generate_image",
    "call_mcp_tool",
    "list_resources",
    "read_resource",
}

PRESETS = {
    "read-only": [
        "view_file", "list_dir", "grep_search", "find_by_name",
        "search_web", "read_url_content", "send_message",
    ],
    "verifier": [
        "view_file", "list_dir", "grep_search", "find_by_name",
        "run_command", "manage_task", "search_web", "read_url_content", "send_message",
    ],
    "builder": [
        "view_file", "list_dir", "grep_search", "find_by_name",
        "write_to_file", "replace_file_content", "run_command", "manage_task",
        "search_web", "read_url_content", "send_message",
    ],
    "orchestrator": [
        "view_file", "list_dir", "grep_search", "find_by_name",
        "write_to_file", "replace_file_content", "run_command", "manage_task",
        "send_message", "invoke_subagent", "define_subagent", "manage_subagents",
        "schedule", "ask_question", "search_web", "read_url_content",
    ],
}

def slugify(raw: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", raw.lower()).strip("-")
    return s

def parse_agency_md(path: Path) -> tuple[str, str, str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise SystemExit(f"Invalid agency agent file (missing frontmatter): {path}")
    end_idx = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is None:
        raise SystemExit(f"Invalid agency agent file (unclosed frontmatter): {path}")

    fm_lines = lines[1:end_idx]
    body = "\n".join(lines[end_idx + 1:]).strip()
    meta: dict[str, str] = {}
    cur_key = None
    for line in fm_lines:
        m = re.match(r"^([a-zA-Z0-9_-]+):\s*(.*)$", line)
        if m:
            cur_key = m.group(1)
            val = m.group(2).strip()
            if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            meta[cur_key] = val
        elif cur_key and re.match(r"^\s+\S", line):
            meta[cur_key] = (meta[cur_key] + " " + line.strip()).strip()
        else:
            cur_key = None

    raw_name = meta.get("name") or path.stem
    raw_desc = meta.get("description") or f"Specialist subagent converted from {path.name}."
    return slugify(raw_name), raw_desc, body

body = ""
if from_agency:
    src_path = Path(from_agency).expanduser().resolve()
    if not src_path.is_file():
        raise SystemExit(f"Agency source file not found: {src_path}")
    parsed_slug, parsed_desc, parsed_body = parse_agency_md(src_path)
    if not name:
        name = parsed_slug
    if not description:
        description = parsed_desc
    body = parsed_body

if not name or not description:
    raise SystemExit("Both --name and --description are required (or provide --from-agency).")

name = slugify(name)
if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name):
    raise SystemExit(f"Invalid subagent name '{name}'. Must be lowercase kebab-case.")

if model not in ("inherit", "flash_lite", "flash", "pro"):
    raise SystemExit(f"Invalid --model '{model}'.")
if main_agent not in ("true", "false"):
    raise SystemExit(f"Invalid --main-agent '{main_agent}'.")
if policy not in ("auto", "sandbox", "off", "eager"):
    raise SystemExit(f"Invalid --policy '{policy}'.")

if tools_csv:
    tools = [t.strip() for t in tools_csv.split(",") if t.strip()]
    unknown = [t for t in tools if t not in VALID_TOOLS]
    if unknown:
        raise SystemExit(
            f"Unknown Antigravity tool(s): {', '.join(unknown)}. "
            f"Valid tools: {', '.join(sorted(VALID_TOOLS))}"
        )
else:
    if role_preset not in PRESETS:
        raise SystemExit(f"Invalid --role-preset '{role_preset}'. Expected: {', '.join(PRESETS)}")
    tools = PRESETS[role_preset]

if not body:
    if prompt_body:
        body = prompt_body.strip()
    else:
        title = " ".join(w.capitalize() for w in name.split("-"))
        body = (
            f"# {title}\n\n"
            f"You are **{title}**, a specialized engineering subagent operating under the AgentsV2 lifecycle.\n\n"
            "## Core Mission\n\n"
            f"- {description}\n"
            "- Follow canonical project documentation (`docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/TASKS.md`).\n\n"
            "## Critical Rules\n\n"
            "- **Docs Compliance**: Never invent undocumented contracts; report doc gaps to the orchestrator.\n"
            "- **Evidence First**: Cite exact file paths, line numbers, commands executed, and observed outputs.\n"
            "- **English Only**: Keep all technical outputs, specs, and generated artifacts in English."
        )

if scope == "project":
    out_dir = Path(project).expanduser().resolve() / ".agents" / "agents"
elif scope == "global":
    out_dir = Path.home() / ".gemini" / "config" / "agents"
else:
    raise SystemExit(f"Invalid --scope '{scope}'. Expected 'project' or 'global'.")

out_dir.mkdir(parents=True, exist_ok=True)
out_file = out_dir / f"{name}.md"
if out_file.exists() and not overwrite:
    raise SystemExit(f"Target subagent already exists: {out_file} (pass --overwrite to replace)")

def yaml_quote(val: str) -> str:
    return "'" + val.replace("'", "''") + "'"

tools_yaml = "\n".join(f"  - {t}" for t in tools)
content = (
    "---\n"
    f"name: {name}\n"
    f"description: {yaml_quote(description)}\n"
    "tools:\n"
    f"{tools_yaml}\n"
    f"mainAgent: {main_agent}\n"
    "subagent: true\n"
    f"model: {model}\n"
    f"commandExecutionPolicy: {policy}\n"
    "inheritMcp: true\n"
    "inheritCustomizations: true\n"
    "---\n\n"
    f"{body}\n"
)

out_file.write_text(content, encoding="utf-8")
print(f"Created Antigravity custom subagent: {out_file}")
PY
