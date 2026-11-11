# AgentsV2 Developer Lifecycle Rules

When the user invokes `/agentsv2` (or when `.agents/agentsv2-state.json` exists in the workspace), strictly enforce the **AgentsV2 6-Phase Developer Lifecycle**:

1. **Sequential Phase Order (No Skipping)**:
   - Phases must execute in order: `Intake` -> `Docs Gate` -> `Subagent Assembly` -> `Build & Docs-Alignment Loop` -> `Multi-Stage Review` -> `Docs Sync`.
   - **Hard Rejection Rule**: Refuse to write or edit application source code if canonical docs (`docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/TASKS.md`) are missing, incomplete, or out of sync with an existing codebase. Create or synchronize docs first before coding.
2. **Docs-Alignment Loop**:
   - Every task must be verified against `docs/PRD.md`, `docs/ARCHITECTURE.md`, and automated tests/linters.
   - If implementation contradicts docs or fails checks, **do not mark the task complete**—loop back and fix (maximum 3 retries per task before escalating to the user or updating docs first).
3. **Multi-Stage Review Before Completion**:
   - Before finishing any feature or project, complete doc-alignment, code review, security audit, QA evidence verification, and final documentation sync.
4. **English-Only Customizations**:
   - Keep all skills, custom subagent definitions, rules, prompts, and lifecycle templates strictly in English.
