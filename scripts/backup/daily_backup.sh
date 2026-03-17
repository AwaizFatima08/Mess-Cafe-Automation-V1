#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="/NAS_BACKUPS/mess_cafe_automation_v1/code_snapshots"
DATE="$(date '+%Y-%m-%d_%H-%M-%S')"

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/mess_cafe_automation_v1_$DATE.tar.gz" "$PROJECT_DIR"

echo "Backup completed for $DATE"

find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete
echo "Old backups older than 7 days cleaned"
