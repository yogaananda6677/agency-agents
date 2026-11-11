---
name: agentsv2-docs-sync
description: Synchronizes project documentation (ARCHITECTURE.md, TASKS.md, README.md, CHANGELOG.md, and API specs) with the final verified implementation before closing a milestone. Use after /agentsv2-review passes.
---

# AgentsV2 Post-Change Documentation Sync

Use this skill in Phase 5 (`docs_sync`) after `/agentsv2-review` returns `VERDICT: READY FOR RELEASE` (or whenever code changes require updating docs).

## Workflow

1. **Delegate Audit & Sync (`agentsv2-tech-writer`)**:
   - Inspect `git diff` / changed files since milestone start.
   - Verify `docs/TASKS.md` accurately marks completed tasks `[x]` and records any deferred follow-ups cleanly.
   - Update `docs/ARCHITECTURE.md` if any module paths, env vars, schemas, or endpoints evolved during Phase 3.
   - Update `README.md` (setup commands, usage examples, env variables) and `CHANGELOG.md` (if present or requested).
2. **Verify Accuracy**:
   Resolve `AGENTSV2_ROOT` to `<project_root>/.agents/plugins/agentsv2` if present, otherwise `~/.gemini/config/plugins/agentsv2`:
   - Confirm every referenced file path, command, flag, and symbol exists verbatim in the repository.
   - Run `bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/check-docs-alignment.sh" --project "<project_root>" --require-all-tasks-done`.
3. **Close Lifecycle State**:
   ```bash
   bash "$AGENTSV2_ROOT/skills/agentsv2/scripts/init-project.sh" --project "<project_root>" --phase complete --docs-synced true --workflow-active false
   ```
   - Only after `docs_synced=true` and `review_status=PASS` should the workflow conclude.
