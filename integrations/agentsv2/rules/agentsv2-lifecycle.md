---
trigger: model_decision
description: Enforcement rules for AgentsV2 phase-gate rejections, brownfield documentation synchronization, bounded docs-alignment retry loops, and safe Antigravity subagent creation.
---

# AgentsV2 Lifecycle Enforcement & Subagent Safety

## 1. Documentation-First Rejection Protocol
- Never bypass Phase 1 (`docs_gate`) when starting a new project or continuing an existing project whose documentation is missing or stale.
- If requested to implement a feature before `docs/PRD.md`, `docs/ARCHITECTURE.md`, and `docs/TASKS.md` exist and reflect current reality:
  1. Explicitly reject jumping directly to implementation.
  2. List the missing or outdated documentation artifacts.
  3. Route immediately to `agentsv2-pm`, `agentsv2-architect`, and `agentsv2-tech-writer` to generate or sync documentation first.

## 2. Bounded Docs-Alignment Loop
- After implementing each task in `docs/TASKS.md`:
  1. Verify behavior, data schemas, API contracts, and file paths match `docs/PRD.md` and `docs/ARCHITECTURE.md`.
  2. Run project tests, typechecks, and linters.
  3. On mismatch or failure, return exact findings to the implementing subagent and retry (up to `max_retries: 3`).
  4. Never silently diverge from docs to make tests pass; if requirements changed, update the docs first with user confirmation, then update code.

## 3. Custom Subagent Creation Guardrails
- When defining persistent subagents (`.agents/agents/<name>.md` or `~/.gemini/config/agents/<name>.md`) or transient subagents (`define_subagent`):
  - Only include verified Antigravity tool names (`view_file`, `list_dir`, `grep_search`, `find_by_name`, `write_to_file`, `replace_file_content`, `run_command`, `manage_task`, `send_message`, `invoke_subagent`, `define_subagent`, `manage_subagents`, `schedule`, `ask_question`, `search_web`, `read_url_content`).
  - Never include misspelled or unknown tool names (which can hang subagent execution).
  - Omit `write_to_file`, `replace_file_content`, and `run_command` on read-only reviewer/auditor subagents.
