# AgentsV2 Developer Subagent Roster

## Core Pre-Built Subagents

| Subagent `TypeName` | Role | Tools Scope | When to Invoke |
| :--- | :--- | :--- | :--- |
| `agentsv2-orchestrator` | Pipeline Controller | Full + Subagents | Top-level multi-phase coordination |
| `agentsv2-pm` | Product Manager & Planner | Read + Write + Shell | Authoring/updating `docs/PRD.md` and `docs/TASKS.md` |
| `agentsv2-architect` | Software & Systems Architect | Read + Write + Shell | Designing/auditing `docs/ARCHITECTURE.md`, APIs, and schemas |
| `agentsv2-tech-writer` | Tech Writer & Doc-Sync Auditor | Read + Write + Shell | Brownfield doc recovery, doc-drift audits, Phase 5 docs sync |
| `agentsv2-backend` | Backend & DB Engineer | Read + Write + Shell | APIs, services, DB migrations, server tests |
| `agentsv2-frontend` | Frontend Web Engineer | Read + Write + Shell | UI components, state management, frontend tests |
| `agentsv2-mobile` | Mobile Engineer | Read + Write + Shell | Flutter / iOS / Android / React Native features and widget tests |
| `agentsv2-devops` | DevOps & Infra Engineer | Read + Write + Shell | CI/CD, Dockerfiles, environment configs, deployment scripts |
| `agentsv2-code-reviewer` | Senior Code Reviewer | **Read-Only** | Spec traceability, clean code, modularity, and PR review |
| `agentsv2-security-auditor` | Security Auditor | **Read-Only** | OWASP checks, auth boundaries, secrets, injection flaws |
| `agentsv2-qa-evidence` | QA & Evidence Collector | Read + Shell (No Edit) | Running test suites, linters, typechecks, and verifying AC proof |
| `agentsv2-reality-checker` | Final Release Gatekeeper | Read + Shell (No Edit) | Adversarial verification before closing a milestone |

## Built-In Antigravity Subagents

- `research`: Fast read-only codebase sweeps and large-repo reconnaissance.
- `self`: Parallel identical worker clones (e.g., auditing multiple independent files/screens concurrently).

## Creating Additional Specialist Subagents

When a project needs domain expertise beyond the core 12 (e.g., Rust refactoring, Smart Contracts, ML/RAG pipelines, PostgreSQL tuning), invoke `/agentsv2-create-subagent` or use `define_subagent` with exact verified tool names.
