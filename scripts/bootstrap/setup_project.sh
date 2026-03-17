#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
BACKUP_SCRIPT_DIR="$PROJECT_DIR/scripts/backup"
STATE_SCRIPT_DIR="$PROJECT_DIR/project_state/scripts"

echo "========================================"
echo "MESS & CAFE AUTOMATION V1 - BOOTSTRAP"
echo "Project: $PROJECT_DIR"
echo "========================================"

mkdir -p "$LOG_DIR"
mkdir -p "$PROJECT_DIR/scripts/bootstrap"

echo "Created/verified required directories."

chmod +x "$BACKUP_SCRIPT_DIR"/*.sh || true
chmod +x "$STATE_SCRIPT_DIR"/*.sh || true
chmod +x "$PROJECT_DIR/scripts/bootstrap"/*.sh || true

echo "Executable permissions applied."

echo "Checking required tools..."
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash not found"; exit 1; }

if command -v flutter >/dev/null 2>&1; then
  echo "Flutter found: $(flutter --version | head -n 1)"
else
  echo "WARNING: Flutter not found in PATH"
fi

if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Git repository check: OK"
else
  echo "ERROR: $PROJECT_DIR is not a git repository"
  exit 1
fi

echo "Current branch: $(git -C "$PROJECT_DIR" branch --show-current)"
echo "Remote: $(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo 'No origin configured')"

echo "Bootstrap completed successfully."
