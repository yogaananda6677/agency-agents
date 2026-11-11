---
name: agentsv2-review
description: Executes the multi-stage AgentsV2 developer review lifecycle (Docs Traceability, Code Review, Security Audit, QA Evidence, and Reality Check) and loops fixes back to builders on failure. Use before completing any feature, milestone, or release.
---

# AgentsV2 Multi-Stage Review Lifecycle

Use this skill in Phase 4 (`review`) or whenever reviewing an implementation against project documentation and production standards.

## Review Pipeline Stages

Execute stages in order (Stages 1 & 2 may run concurrently via `invoke_subagent`):

### Stage 1: Docs Alignment & Code Quality (`agentsv2-code-reviewer`)
- Compare every changed file and symbol against `docs/PRD.md`, `docs/ARCHITECTURE.md`, and `docs/TASKS.md`.
- Check modularity, error handling, edge cases, duplication, and test assertions.
- Required output: `STATUS: APPROVED` or `STATUS: NEEDS WORK` with exact `file:line` findings.

### Stage 2: Security & Privacy Audit (`agentsv2-security-auditor`)
- Inspect authentication, authorization, input validation, database queries, hardcoded secrets, and error exposure.
- Required output: `SECURITY STATUS: PASS` or `SECURITY STATUS: FAIL`.

### Stage 3: Empirical QA & Evidence Verification (`agentsv2-qa-evidence`)
- Run project unit tests, integration tests, static analysis, typechecks, linters, and build commands **after the latest edits**.
- Verify zero skipped/relaxed checks and verify every `FR-xxx` acceptance criterion.
- Required output: `QA VERDICT: PASS` or `QA VERDICT: FAIL` with exact commands and counts.

### Stage 4: Final Adversarial Gatekeeper (`agentsv2-reality-checker`)
- Cross-check `docs/TASKS.md` (`[x]` completeness), Stages 1-3 reports, `git status` / `git diff`, and spot-check code for TODOs/stubs/doc drift.
- Required output: `VERDICT: READY FOR RELEASE` or `VERDICT: NEEDS WORK`.

## Loop-Back Protocol on Rejection

If **any** stage returns `NEEDS WORK` or `FAIL`:
1. Update state: `phase="build"`, `review_status="NEEDS_WORK"`.
2. Route findings directly to the owning builder subagent (`agentsv2-backend`, `agentsv2-frontend`, `agentsv2-mobile`, `agentsv2-devops`) with exact `file:line` and doc references.
3. Re-run affected verification tests, then re-run failed review stages (bounded to max 3 review loops before escalating blockers to the user).

## Completion

Resolve `AGENTSV2_ROOT` to `<project_root>/.agents/plugins/agentsv2` if present, otherwise `~/.gemini/config/plugins/agentsv2`:
- Save a concise summary if needed using `$AGENTSV2_ROOT/skills/agentsv2/resources/templates/REVIEW_REPORT.md`.
- Advance state via `bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --phase docs_sync --review-status PASS` and proceed to `/agentsv2-docs-sync`.
