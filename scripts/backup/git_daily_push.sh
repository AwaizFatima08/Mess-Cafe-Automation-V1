#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/humayun/projects/mess_cafe_automation_v1"
cd "$REPO_DIR"

git add .

if git diff --cached --quiet; then
  echo "No changes to commit"
  exit 0
fi

git commit -m "Daily backup commit $(date '+%d-%b-%Y %H:%M')"
git push
echo "Git push completed"
