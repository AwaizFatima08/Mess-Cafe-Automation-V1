#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

ALLOWED_BRANCHES=("main")
CURRENT_BRANCH="$(git branch --show-current)"

echo "---- Git Status Before Commit ----"
git status

branch_allowed=false
for b in "${ALLOWED_BRANCHES[@]}"; do
  if [[ "$CURRENT_BRANCH" == "$b" ]]; then
    branch_allowed=true
    break
  fi
done

if [[ "$branch_allowed" != true ]]; then
  echo "ERROR: Current branch '$CURRENT_BRANCH' is not allowed for daily maintenance push."
  echo "Allowed branches: ${ALLOWED_BRANCHES[*]}"
  exit 1
fi

git add .

if git diff --cached --quiet; then
  echo "No changes to commit"
  exit 0
fi

COMMIT_MSG="Daily maintenance: project state + backup ($(date '+%d-%b-%Y %H:%M'))"

git commit -m "$COMMIT_MSG"

echo "---- Pushing to remote branch: $CURRENT_BRANCH ----"
git push origin "$CURRENT_BRANCH"

echo "Git push completed successfully"
