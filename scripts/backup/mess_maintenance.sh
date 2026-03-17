#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/maintenance_$(date '+%Y-%m-%d_%H-%M').log"

echo "========================================" | tee -a "$LOG_FILE"
echo "MESS AUTOMATION DAILY MAINTENANCE START" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

echo "Updating project status..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/project_state/scripts/update_project_status.sh" | tee -a "$LOG_FILE"

echo "Running backup..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/scripts/backup/daily_backup.sh" | tee -a "$LOG_FILE"

echo "Running git push..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/scripts/backup/git_daily_push.sh" | tee -a "$LOG_FILE"

echo "========================================" | tee -a "$LOG_FILE"
echo "MAINTENANCE COMPLETED" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
