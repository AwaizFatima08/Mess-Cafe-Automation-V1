#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/humayun/projects/mess_cafe_automation_v1"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/maintenance_$(date '+%Y-%m-%d_%H-%M').log"

echo "========================================" | tee -a "$LOG_FILE"
echo "MESS AUTOMATION DAILY MAINTENANCE START" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# 1. Update project status
echo "Updating project status..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/project_state/scripts/update_project_status.sh" | tee -a "$LOG_FILE"

# 2. Run backup
echo "Running backup..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/scripts/backup/daily_backup.sh" | tee -a "$LOG_FILE"

# 3. Git push
echo "Running git push..." | tee -a "$LOG_FILE"
bash "$PROJECT_DIR/scripts/backup/git_daily_push.sh" | tee -a "$LOG_FILE"

# 4. Run project status updater (if separate)
if [[ -f "$PROJECT_DIR/project_state/scripts/update_project_status.sh" ]]; then
  echo "Refreshing project state..." | tee -a "$LOG_FILE"
  bash "$PROJECT_DIR/project_state/scripts/update_project_status.sh" | tee -a "$LOG_FILE"
fi

echo "========================================" | tee -a "$LOG_FILE"
echo "MAINTENANCE COMPLETED" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
