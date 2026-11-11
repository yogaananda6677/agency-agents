# AgentsV2 Developer Extension

This fork (`yogaananda6677/agency-agents`) extends [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) with **`agentsv2`**, an English-only developer orchestration plugin built natively for **Google Antigravity** (App, CLI, and IDE).

## Key Additions

1. **One-Call Developer Entrypoint (`/agentsv2`)**
   - Works seamlessly for **Greenfield** (new projects) and **Brownfield** (continuing existing codebases).
   - Location: [SKILL.md](integrations/agentsv2/skills/agentsv2/SKILL.md)
2. **Strict Phase-Ordering & Doc-First Rejection Gate (`/agentsv2-doc-gate` + `hooks.json`)**
   - Rejects jumping into implementation code before canonical documentation (`docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/TASKS.md`) exists and reflects current code reality.
   - Enforced both behaviorally (skills + rules) and deterministically via [gate-hook.py](integrations/agentsv2/scripts/gate-hook.py) whenever `.agents/agentsv2-state.json` is active in a project.
3. **Self-Correcting Docs-Alignment Loop**
   - Each task runs an **Implement -> Verify vs. Docs & Tests -> Loop Back** cycle bounded at 3 retries before escalating or updating docs first.
4. **Native Custom Subagents & Subagent Factory (`/agentsv2-create-subagent`)**
   - 12 pre-built Antigravity subagents in [integrations/agentsv2/agents](integrations/agentsv2/agents).
   - Generate new custom subagents or convert any of the 230+ upstream `agency-agents` personas via [scripts/create-subagent.sh](scripts/create-subagent.sh) with validated Antigravity tool allowlists.
5. **Multi-Stage Review & Docs-Sync Lifecycle (`/agentsv2-review`, `/agentsv2-docs-sync`)**
   - Doc traceability review, read-only code review, security audit, empirical QA verification, adversarial reality check, and final doc sync.

## Installation & Verification

```bash
# Validate plugin schemas, tool allowlists, and hooks
./scripts/validate-agentsv2.sh

# Run full automated test suite
./scripts/test-agentsv2.sh

# Install the AgentsV2 Antigravity plugin globally (~/.gemini/config/plugins/agentsv2)
./scripts/install-agentsv2.sh --global

# Optional: install plus upstream developer divisions (engineering, testing, security, etc.)
./scripts/install-agentsv2.sh --global --with-dev-skills
```
