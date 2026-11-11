# AgentsV2 Rejection & Bounded Loop Rules

## 1. Mandatory Phase-Gate Rejection Rules

Reject advancing and route back to the prerequisite phase whenever ANY of the following occurs:

| Violation Attempted | Rejection Reason | Required Recovery Action |
| :--- | :--- | :--- |
| Writing code before `docs/PRD.md` exists | Requirements and acceptance criteria are undefined | Invoke `agentsv2-pm` to author `docs/PRD.md` |
| Writing code before `docs/ARCHITECTURE.md` exists | System boundaries, schemas, and contracts are undefined | Invoke `agentsv2-architect` to author `docs/ARCHITECTURE.md` |
| Writing code before `docs/TASKS.md` exists | Work has no dependency order or verification checklist | Invoke `agentsv2-pm` to author `docs/TASKS.md` |
| Continuing an existing project whose docs contradict its code | Implementation would compound architectural drift | Invoke `agentsv2-tech-writer` + `agentsv2-architect` to sync docs first |
| Advancing to Task `N+1` while Task `N` has failing tests or unverified doc compliance | Broken foundations cascade across tasks | Enter Phase 3 loop on Task `N` until fixed |
| Skipping Phase 4 Review or Phase 5 Docs Sync | Unaudited code or stale documentation shipped | Run `/agentsv2-review` and `/agentsv2-docs-sync` |

## 2. Bounded Docs-Alignment Loop Protocol

When a task fails automated tests, linters, or docs compliance:

1. **Diagnose**: Record the exact mismatch (`Expected per docs/<file>.md` vs. `Observed in <source>:<line>` or `Command output`).
2. **Increment Retry Counter**: Track `task_retries.<task_id>` in `.agents/agentsv2-state.json`.
3. **Retry (`attempts <= 3`)**: Send the exact discrepancy list to the responsible builder subagent and re-verify after fixes.
4. **Loop Breaker (`attempts > 3`)**:
   - Stop automatic retries immediately to prevent token burn and thrashing.
   - Determine root cause:
     - **Spec/Doc flaw**: If the documented design is infeasible or ambiguous, pause coding, propose the concrete doc revision to the user (`paused_waiting_for_user: true`), update docs first once confirmed, reset retry count, and resume.
     - **Persistent technical blocker**: Present the 3 attempt summaries, exact errors, and recommended resolution paths to the user and await guidance.
