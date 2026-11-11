# AgentsV2 Lifecycle Phases Reference

| Phase | Name | Owner Subagents | Mandatory Entry Criteria | Mandatory Exit Gate |
| :--- | :--- | :--- | :--- | :--- |
| **0** | **Intake & Repo Scan** | `agentsv2-orchestrator` | User invokes `/agentsv2` with goal or repo | Mode classified (`greenfield` / `brownfield-*` / `resume-active`); `.agents/agentsv2-state.json` initialized |
| **1** | **Documentation Gate** | `agentsv2-pm`, `agentsv2-architect`, `agentsv2-tech-writer` | Phase 0 complete | `docs/PRD.md`, `docs/ARCHITECTURE.md`, and `docs/TASKS.md` exist, reflect repo reality, pass `check-docs-alignment.sh`, and `docs_verified=true` |
| **2** | **Subagent Assembly** | `agentsv2-orchestrator` | Phase 1 exit gate passed (`phase=build`) | Required subagents selected or created via `/agentsv2-create-subagent` / `define_subagent` |
| **3** | **Build & Alignment Loop** | `agentsv2-backend`, `agentsv2-frontend`, `agentsv2-mobile`, `agentsv2-devops` | Phase 2 complete + dependency-ordered `docs/TASKS.md` | Every task implemented, verified against docs, tests/linters pass, `[x]` updated in `docs/TASKS.md` |
| **4** | **Multi-Stage Review** | `agentsv2-code-reviewer`, `agentsv2-security-auditor`, `agentsv2-qa-evidence`, `agentsv2-reality-checker` | All tasks in `docs/TASKS.md` complete | All review stages pass; `agentsv2-reality-checker` outputs `VERDICT: READY FOR RELEASE`; `review_status=PASS` |
| **5** | **Docs Sync & Handover** | `agentsv2-tech-writer`, `agentsv2-orchestrator` | Phase 4 `PASS` | `README.md`, `CHANGELOG.md`, `docs/*` updated and verified; `docs_synced=true`, `phase=complete`, `workflow_active=false` |

## Brownfield vs. Greenfield Rules

- **Greenfield**: Start with requirements elicitation (if ambiguous, set `paused_waiting_for_user=true` and ask clarifying questions before locking PRD/Architecture), author `PRD.md`, `ARCHITECTURE.md`, and `TASKS.md`, then build.
- **Brownfield (Existing Project without Docs)**: **Never** jump straight into editing existing code. First inspect manifests (`package.json`, `go.mod`, `pubspec.yaml`, `pyproject.toml`, `Cargo.toml`), routes, models, and tests to reverse-engineer baseline `docs/PRD.md`, `docs/ARCHITECTURE.md`, and `docs/TASKS.md`, then add the new feature delta to those docs before writing code.
- **Brownfield (Existing Project with Docs)**: Audit docs against the actual source files first. If docs are outdated or contradict current code, repair the docs in Phase 1 before implementing new tasks.
