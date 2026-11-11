---
name: agentsv2-create-subagent
description: Creates new Antigravity custom subagents (.agents/agents/<name>.md, ~/.gemini/config/agents/<name>.md, or transient define_subagent) and converts upstream agency-agents personas into validated Antigravity subagents. Use when you need a new specialized subagent.
---

# AgentsV2 Custom Subagent Factory

Use this skill when the developer asks to create a new subagent, or when `/agentsv2` Phase 2 detects a domain specialty not covered by the default 12 `agentsv2-*` subagents.

> **Language Rule**: Always generate subagent definitions, descriptions, and system prompts in **English**.

## Option 1: Persistent Custom Subagent (`.md` File)

Resolve `AGENTSV2_ROOT` to `<project_root>/.agents/plugins/agentsv2` if present, otherwise `~/.gemini/config/plugins/agentsv2`.
Generate a validated Markdown subagent using `create-subagent.sh` (run with `--help` first if unsure of flags):

```bash
# Create a project-scoped subagent (.agents/agents/<name>.md)
bash "$AGENTSV2_ROOT/skills/agentsv2-create-subagent/scripts/create-subagent.sh" \
  --name "rust-performance-reviewer" \
  --description "Read-only Rust code reviewer specializing in async safety, zero-copy parsing, and benchmark regression checks." \
  --role-preset read-only \
  --scope project \
  --project "<project_root>"
```

Or convert any upstream persona from the forked `agency-agents` repository into a native Antigravity subagent:

```bash
bash "$AGENTSV2_ROOT/skills/agentsv2-create-subagent/scripts/create-subagent.sh" \
  --from-agency "<repo_root>/engineering/engineering-database-optimizer.md" \
  --role-preset builder \
  --scope project \
  --project "<project_root>"
```

### Role Presets (Validated Tool Allowlists)

| Preset | Permitted Tools | Use Case |
| :--- | :--- | :--- |
| `read-only` | `view_file`, `list_dir`, `grep_search`, `find_by_name`, `search_web`, `read_url_content`, `send_message` | Code reviewers, security auditors, architecture inspectors |
| `verifier` | `read-only` + `run_command`, `manage_task` | QA test runners, benchmarkers, reality checkers |
| `builder` | `verifier` + `write_to_file`, `replace_file_content` | Feature engineers, DB/DevOps engineers, technical writers |
| `orchestrator` | `builder` + `invoke_subagent`, `define_subagent`, `manage_subagents`, `schedule`, `ask_question` | Multi-agent coordinators |

## Option 2: Transient Runtime Subagent (`define_subagent`)

For one-off session needs where persistence is unnecessary, call the `define_subagent` tool directly:
- Set `name` (`kebab-case`), concise `description`, `enable_write_tools` (`false` for reviewers, `true` for builders), and an English `system_prompt` structured after `resources/subagent-template.md`.
- Invoke it immediately via `invoke_subagent`.

## Critical Safety Check (Prevent Subagent Hang)

Antigravity can hang if an unrecognized or misspelled tool name is placed in a subagent's `tools:` list. `scripts/create-subagent.sh` automatically validates every tool name against Antigravity's verified toolset before writing the file.
