#!/usr/bin/env bash
# install-agentsv2.sh — Install the AgentsV2 Antigravity developer plugin globally or per-project.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-agentsv2.sh [options]

Options:
  --global               Install globally to ~/.gemini/config/plugins/agentsv2 (default)
  --project <dir>        Install project-locally to <dir>/.agents/plugins/agentsv2
  --link                 Create a symlink instead of copying files
  --with-dev-skills      Also convert & install upstream developer skills (engineering,
                         testing, security, product, project-management, design) to
                         ~/.gemini/config/skills/
  --dry-run              Print planned actions without writing files
  --help                 Show this help
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/integrations/agentsv2"

MODE="global"
PROJECT_DIR="."
USE_LINK=false
WITH_DEV_SKILLS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global) MODE="global"; shift ;;
    --project) MODE="project"; PROJECT_DIR="${2:?missing directory}"; shift 2 ;;
    --link) USE_LINK=true; shift ;;
    --with-dev-skills) WITH_DEV_SKILLS=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -d "$SRC" ]] || { echo "ERROR: Missing plugin source at $SRC" >&2; exit 1; }

# Always validate plugin before installing
bash "$SCRIPT_DIR/validate-agentsv2.sh"

if [[ "$MODE" == "global" ]]; then
  DEST="${HOME}/.gemini/config/plugins/agentsv2"
else
  DEST="$(cd "$PROJECT_DIR" && pwd)/.agents/plugins/agentsv2"
fi

echo "Install source:      $SRC"
echo "Install destination: $DEST"
echo "Mode:                $MODE (link=$USE_LINK, dry_run=$DRY_RUN)"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would install agentsv2 plugin to $DEST"
else
  mkdir -p "$(dirname "$DEST")"
  rm -rf "$DEST"
  if [[ "$USE_LINK" == "true" ]]; then
    ln -s "$SRC" "$DEST"
  else
    cp -R "$SRC" "$DEST"
    find "$DEST" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
  fi
  echo "[OK] Installed AgentsV2 plugin to $DEST"
fi

if [[ "$WITH_DEV_SKILLS" == "true" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would convert and install upstream developer divisions for antigravity"
  else
    bash "$SCRIPT_DIR/convert.sh" --tool antigravity
    bash "$SCRIPT_DIR/install.sh" --no-interactive --tool antigravity \
      --division engineering,testing,security,product,project-management,design
  fi
fi
