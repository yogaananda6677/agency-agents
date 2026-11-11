---
name: agentsv2-doc-gate
description: Audits project documentation prerequisites and bootstraps or reverse-engineers docs/PRD.md, docs/ARCHITECTURE.md, and docs/TASKS.md before allowing code changes. Use when starting a project without docs, continuing an undocumented codebase, or enforcing Phase 1 doc-first compliance.
---

# AgentsV2 Documentation Gatekeeper

Use this skill whenever documentation is missing, stubbed, or out of sync with the codebase. Implementation **must be rejected** until this gate passes.

## Hard Rejection Policy

If the user or another agent requests implementing code when `docs/PRD.md`, `docs/ARCHITECTURE.md`, or `docs/TASKS.md` are missing or contradict existing code:
1. **Refuse implementation immediately** — state explicitly which documentation prerequisites are missing or stale.
2. **Audit or bootstrap docs first** using the steps below.
3. Only unlock Phase 3 (`build`) after all three canonical documents exist and reflect repository reality.

## Workflow

### Case A: Greenfield (New Project)
1. Clarify core scope, target stack, and constraints if ambiguous (ask concise questions; set `paused_waiting_for_user: true` in `.agents/agentsv2-state.json` while awaiting answers).
2. Invoke `agentsv2-pm` to create `docs/PRD.md` (with `FR-xxx`, `NFR-xxx`, and testable acceptance criteria).
3. Invoke `agentsv2-architect` to design `docs/ARCHITECTURE.md` (stack, directories, data models, API contracts, security boundaries, test commands).
4. Invoke `agentsv2-pm` to create dependency-ordered `docs/TASKS.md` linking every task back to `FR-xxx` and `ARCHITECTURE`.

### Case B: Brownfield (Existing Project Missing or Having Stale Docs)
1. Use `research` or `agentsv2-tech-writer` + `agentsv2-architect` to inspect manifests (`package.json`, `go.mod`, `pubspec.yaml`, `pyproject.toml`), directory structure, routes, models, and existing tests.
2. Reverse-engineer accurate baseline `docs/PRD.md` and `docs/ARCHITECTURE.md` based **only** on observed code (never fabricate features), then append the requested new work delta.
3. Generate or update `docs/TASKS.md` with dependency-ordered tasks for the delta.

## Verification

Resolve `AGENTSV2_ROOT` to `<project_root>/.agents/plugins/agentsv2` if present, otherwise `~/.gemini/config/plugins/agentsv2`:

1. Run `bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/check-docs-alignment.sh" --project "<project_root>"`.
2. Confirm exit code `0` with zero `REJECTED` items.
3. Update `.agents/agentsv2-state.json` via `bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --phase build --docs-verified true --pause false`.
