# Dependency-Ordered Implementation Tasks

- **Project Name**: `<Project Name>`
- **Status**: `ACTIVE | COMPLETED`
- **Last Updated**: `YYYY-MM-DD`

> Execute tasks strictly in order. Do not mark `[x]` until implementation matches `docs/PRD.md` + `docs/ARCHITECTURE.md` AND verification commands pass.

## Task List

### [ ] TASK-001: Foundation & Project Scaffolding
- **Traces To**: `FR-001`, `ARCHITECTURE §2`
- **Owner Subagent**: `agentsv2-backend` / `agentsv2-devops`
- **Depends On**: `None`
- **Deliverables**:
  - Concrete files/modules to create or update
- **Docs-Alignment & Verification Commands**:
  - `<lint/test command>`

### [ ] TASK-002: Core Feature Implementation
- **Traces To**: `FR-001`, `ARCHITECTURE §3-4`
- **Owner Subagent**: `agentsv2-backend` / `agentsv2-frontend`
- **Depends On**: `TASK-001`
- **Deliverables**:
  - Concrete files/modules and unit/integration tests
- **Docs-Alignment & Verification Commands**:
  - `<test command>`
