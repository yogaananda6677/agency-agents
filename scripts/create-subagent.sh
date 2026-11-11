#!/usr/bin/env bash
# create-subagent.sh — Repo-level wrapper for the AgentsV2 subagent factory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="$REPO_ROOT/integrations/agentsv2/skills/agentsv2-create-subagent/scripts/create-subagent.sh"

exec bash "$TARGET" "$@"
