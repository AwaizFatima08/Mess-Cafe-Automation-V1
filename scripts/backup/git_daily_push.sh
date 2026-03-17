#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

echo "---- Git Status Before Commit ----"
git status

git add .

if git diff --cached --quiet; then
  echo "No changes to commit"
  exit 0
fi

COMMIT_MSG="Daily maintenance: project state + backup ($(date '+%d-%b-%Y %H:%M'))"

git commit -m "$COMMIT_MSG"

echo "---- Pushing to remote ----"
git push

echo "Git push completed successfully"
