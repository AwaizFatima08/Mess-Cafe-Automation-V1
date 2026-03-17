#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"

MILESTONE_TAG="${1:-}"
LOG_FILE="$LOG_DIR/maintenance_$(date '+%Y-%m-%d_%H-%M').log"
FAIL_LOG="$LOG_DIR/maintenance_failures.log"

on_error() {
  local exit_code=$?
  echo "========================================" | tee -a "$LOG_FILE"
  echo "MAINTENANCE FAILED at $(date)" | tee -a "$LOG_FILE"
  echo "Exit code: $exit_code" | tee -a "$LOG_FILE"
  echo "See log: $LOG_FILE" | tee -a "$LOG_FILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') | FAILED | exit=$exit_code | $LOG_FILE | tag=${MILESTONE_TAG:-none}" >> "$FAIL_LOG"
  exit "$exit_code"
}

trap on_error ERR

echo "========================================" | tee -a "$LOG_FILE"
echo "MESS AUTOMATION DAILY MAINTENANCE START" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "Project: $PROJECT_DIR" | tee -a "$LOG_FILE"
echo "Milestone tag: ${MILESTONE_TAG:-none}" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

echo "Updating project status..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/project_state/scripts/update_project_status.sh" | tee -a "$LOG_FILE"

echo "Running backup..." | tee -a "$LOG_FILE"
if [[ -n "$MILESTONE_TAG" ]]; then
  bash "$PROJECT_DIR/scripts/backup/daily_backup.sh" "$MILESTONE_TAG" | tee -a "$LOG_FILE"
else
  bash "$PROJECT_DIR/scripts/backup/daily_backup.sh" | tee -a "$LOG_FILE"
fi

echo "Running git push..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/scripts/backup/git_daily_push.sh" | tee -a "$LOG_FILE"

echo "========================================" | tee -a "$LOG_FILE"
echo "MAINTENANCE COMPLETED SUCCESSFULLY" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
