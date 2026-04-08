#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="/mnt/storage/backup/mess_cafe_automation_v1/code_snapshots"
DATE="$(date '+%Y-%m-%d_%H-%M-%S')"
TAG="${1:-}"

mkdir -p "$BACKUP_DIR"

if [[ -n "$TAG" ]]; then
  SAFE_TAG="$(echo "$TAG" | tr ' ' '_' | tr -cd '[:alnum:]_-')"
  BACKUP_FILE="$BACKUP_DIR/mess_cafe_automation_v1_${DATE}_${SAFE_TAG}.tar.gz"
else
  BACKUP_FILE="$BACKUP_DIR/mess_cafe_automation_v1_${DATE}.tar.gz"
fi

tar -czf "$BACKUP_FILE" "$PROJECT_DIR"

echo "Backup completed: $BACKUP_FILE"

find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete
echo "Old backups older than 7 days cleaned"
