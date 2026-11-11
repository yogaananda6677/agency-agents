# AgentsV2 Developer Orchestrator

**AgentsV2** is a customized, English-only developer lifecycle plugin built on top of [agency-agents](https://github.com/msitarzewski/agency-agents) for Google Antigravity (App, CLI, and IDE).

## What It Provides

- **One-Call Developer Entrypoint (`/agentsv2`)**: Seamlessly handles both **Greenfield** (new projects) and **Brownfield** (continuing existing codebases).
- **Hard Documentation-First Gate (`/agentsv2-doc-gate` + `hooks.json`)**: Rejects out-of-order implementation when canonical docs (`docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/TASKS.md`) are missing, empty, or stale—requiring docs creation/synchronization before coding.
- **Self-Correcting Docs-Alignment Loop**: Every task runs an **Implement -> Verify vs. Docs & Tests -> Loop Back** cycle (bounded at 3 retries before user escalation) so code never drifts from specifications.
- **Subagent Factory (`/agentsv2-create-subagent`)**: Create new Antigravity custom subagents (`.agents/agents/<name>.md`, `~/.gemini/config/agents/<name>.md`, or transient `define_subagent`) with validated Antigravity tool allowlists, or convert any upstream `agency-agents` persona on demand.
- **Multi-Stage Review Lifecycle (`/agentsv2-review` & `/agentsv2-docs-sync`)**: Enforces Doc-Alignment Traceability, Code Review, Security Audit, QA Evidence Verification, Reality Check sign-off, and Post-Change Docs Synchronization.

## Bundled Components

### Skills
- `agentsv2` — Primary orchestrator skill for creating or continuing software projects
- `agentsv2-doc-gate` — Prerequisite documentation audit and bootstrapper
- `agentsv2-create-subagent` — Subagent factory & upstream persona converter
- `agentsv2-review` — Multi-stage developer review lifecycle
- `agentsv2-docs-sync` — Final documentation synchronization and release readiness

### Custom Subagents (`agents/`)
- `agentsv2-orchestrator` (Primary / Subagent pipeline controller)
- `agentsv2-pm` (PRD & dependency-ordered task planner)
- `agentsv2-architect` (System, API, DB, & UX architect)
- `agentsv2-tech-writer` (Canonical documentation & brownfield doc-sync engineer)
- `agentsv2-backend`, `agentsv2-frontend`, `agentsv2-mobile`, `agentsv2-devops`
- `agentsv2-code-reviewer`, `agentsv2-security-auditor` (read-only reviewers)
- `agentsv2-qa-evidence`, `agentsv2-reality-checker` (verification & final gatekeeper)

### Quick Usage

Invoke in Antigravity chat:

```text
/agentsv2 Build a task management REST API in Go with PostgreSQL
```

Or in an existing repository:

```text
/agentsv2 Continue this project and implement offline sync cleanly
```
