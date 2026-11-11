---
name: agentsv2
description: Complete developer orchestration lifecycle for starting new projects or continuing existing codebases. Enforces strict doc-first phase ordering (rejecting code before canonical docs exist), creates/coordinates specialized subagents, runs bounded Dev-vs-Docs verification loops, and completes multi-stage code/security/QA/reality reviews.
---

# AgentsV2 Developer Lifecycle Orchestrator

Use this skill whenever the user invokes `/agentsv2` or asks to build a new project, add a major feature, or continue an existing codebase with structured engineering rigor, subagents, doc-first enforcement, and lifecycle reviews.

> **Language Rule**: All generated skills, custom subagent definitions, rules, templates, and technical documentation in this workflow must be written in **English**.

## Execution Overview

Strictly follow the 6 phases below **in exact sequential order**. Never skip a phase.

```text
Phase 0: Intake & Repo Scan
   │
   ▼
Phase 1: Documentation Gate ──(missing or stale docs)──▶ REJECT CODING; create/sync docs first
   │ (docs verified)
   ▼
Phase 2: Subagent Assembly & Factory (select roster or create missing subagents)
   │
   ▼
Phase 3: Ordered Build & Docs-Alignment Loop (per task: Dev -> Verify vs. Docs & Tests -> Loop <= 3)
   │ (all planned tasks pass)
   ▼
Phase 4: Multi-Stage Review Lifecycle (Doc + Code + Security + QA + Reality Checker)
   │ (PASS)
   ▼
Phase 5: Docs Sync & Handover Report
```

---

## Step-by-Step Workflow

> **Plugin Path**: Resolve `AGENTSV2_ROOT` to `.agents/plugins/agentsv2` if present in the project, otherwise `~/.gemini/config/plugins/agentsv2` (same directory containing this `skills/agentsv2/` folder).

### Phase 0: Project Intake & Mode Detection

1. Inspect the target workspace using `init-project.sh`:
   ```bash
   bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --detect
   ```
2. Classify the project mode:
   - **`greenfield`**: Empty or freshly initialized repo with no application source code yet.
   - **`brownfield-no-docs`**: Existing codebase without canonical `docs/PRD.md`, `docs/ARCHITECTURE.md`, and `docs/TASKS.md` (or with stale stub docs).
   - **`brownfield-with-docs`**: Existing codebase with canonical docs ready for increment planning.
   - **`resume-active`**: Existing `.agents/agentsv2-state.json` from an in-progress workflow.
3. Initialize or load workflow state:
   ```bash
   bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --init
   ```
   - State is stored in `<project_root>/.agents/agentsv2-state.json`.
   - While `phase` is `"intake"` or `"docs_gate"` (or `docs_verified` is `false`), the active lifecycle hook rejects writing or editing application source files.

### Phase 1: Mandatory Documentation Gate (Hard Rejection Rule)

**CRITICAL GATE**: You **MUST REJECT** any request to write or modify implementation code (`src/`, `lib/`, `app/`, services, UI, or migrations) until canonical documentation exists and matches current codebase reality.

1. Run the prerequisite checker:
   ```bash
   bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/check-docs-alignment.sh" --project "<project_root>"
   ```
2. If any required document (`docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/TASKS.md`) is missing, stubbed, or out of sync with existing code:
   - **Refuse implementation** and announce clearly which Phase 1 prerequisites are missing.
   - Invoke `agentsv2-pm`, `agentsv2-architect`, and `agentsv2-tech-writer` via `invoke_subagent` (or use `/agentsv2-doc-gate`) using the templates in `$AGENTSV2_ROOT/skills/agentsv2/resources/templates/`:
     - `PRD.md` -> `<project_root>/docs/PRD.md`
     - `ARCHITECTURE.md` -> `<project_root>/docs/ARCHITECTURE.md`
     - `TASKS.md` -> `<project_root>/docs/TASKS.md`
   - For **brownfield** projects, inspect the existing codebase first so docs accurately capture existing architecture, schemas, and routes plus the new work delta.
3. Re-run `check-docs-alignment.sh`. Only once it exits `0` (and user review is obtained if ambiguity remains—set `--pause true` while waiting for user answers), advance state:
   ```bash
   bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --phase build --docs-verified true --pause false
   ```
   See [references/rejection-and-loop-rules.md](references/rejection-and-loop-rules.md) for full gatekeeping rules.

### Phase 2: Subagent Team Assembly & Creation

1. Review the task stack against the pre-built developer subagent roster in [references/subagent-roster.md](references/subagent-roster.md).
2. If the project needs a domain specialist not in the default roster (for example, a Rust specialist, GraphQL engineer, or any persona from `yogaananda6677/agency-agents`):
   - Create a persistent project subagent with `/agentsv2-create-subagent` (written to `<project_root>/.agents/agents/<name>.md`), **or**
   - Register a transient runtime subagent with `define_subagent` using only verified Antigravity tool names.

### Phase 3: Ordered Task Execution & Self-Correcting Docs-Alignment Loop

Execute tasks strictly in dependency order from `docs/TASKS.md`. Do **not** jump ahead to dependent tasks.

For **each task**:
1. **Implement**: Spawn the appropriate builder subagent (`agentsv2-backend`, `agentsv2-frontend`, `agentsv2-mobile`, `agentsv2-devops`, or custom specialist) with `invoke_subagent`, passing exact references to `docs/PRD.md`, `docs/ARCHITECTURE.md`, and the target task ID in `docs/TASKS.md`.
2. **Verify vs. Docs & Checks**:
   - Check implemented symbols, API routes, schemas, error codes, and acceptance criteria against `docs/PRD.md` and `docs/ARCHITECTURE.md`.
   - Run the task's build, lint, typecheck, and test commands.
3. **Loop Decision**:
   - **ALIGNED & PASS**: Mark `[x]` in `docs/TASKS.md`, reset retry counter, and proceed to the next task.
   - **DRIFT OR FAIL (retries < 3)**: Do **not** mark complete. Feed the exact doc discrepancy or test failure back to the builder subagent via `send_message` / `invoke_subagent` and **loop** again.
   - **DRIFT OR FAIL (retries >= 3) or SPEC GAP**: Stop looping. Either escalate to the user with concrete options (set `--pause true`), or—if requirements legitimately changed—update `docs/PRD.md` / `docs/ARCHITECTURE.md` **first** via `agentsv2-architect` / `agentsv2-pm`, then resume code alignment.

### Phase 4: Multi-Stage Lifecycle Review

Once all tasks in `docs/TASKS.md` are `[x]`, advance state to `review` and execute `/agentsv2-review`:
```bash
bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --phase review --review-status PENDING
```
1. Run read-only code review (`agentsv2-code-reviewer`) and security audit (`agentsv2-security-auditor`) in parallel.
2. Run QA test/evidence verification (`agentsv2-qa-evidence`).
3. Run final adversarial verification (`agentsv2-reality-checker`).
4. **Loop on Rejection**: If any gate returns `NEEDS WORK` or `FAIL`, set state back to `build`, fix findings via Phase 3 loop, and re-run review.
5. When `agentsv2-reality-checker` emits `VERDICT: READY FOR RELEASE`, update state:
   ```bash
   bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --phase docs_sync --review-status PASS
   ```

### Phase 5: Docs Sync & Handover

Run `/agentsv2-docs-sync` (via `agentsv2-tech-writer`) so `docs/ARCHITECTURE.md`, `docs/TASKS.md`, `README.md`, and `CHANGELOG.md` match final reality. Then mark workflow complete:
```bash
bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --phase complete --docs-synced true --workflow-active false
```
Deliver a concise engineering handover report summarizing verified docs, completed tasks, test/review results, and file links.

---

## Reference Files

- [references/lifecycle-phases.md](references/lifecycle-phases.md) — Detailed phase inputs, outputs, and entry/exit criteria
- [references/subagent-roster.md](references/subagent-roster.md) — Pre-built developer subagents and delegation matrix
- [references/rejection-and-loop-rules.md](references/rejection-and-loop-rules.md) — Strict ordering rules, brownfield handling, and bounded loop breaker logic
