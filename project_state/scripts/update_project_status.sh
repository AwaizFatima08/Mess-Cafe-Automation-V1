#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$HOME/projects/mess_cafe_automation_v1/project_state"
STATUS_FILE="${1:-$BASE_DIR/project_status.md}"
STAMP="$(date '+%d-%b-%Y %H:%M')"
TMP_FILE="$(mktemp)"

cat > "$TMP_FILE" <<EOF
## Update Entry - ${STAMP}

### Completed
-

### Ongoing
-

### Next
-

### Decisions / Risks
-

EOF

if [[ -f "$STATUS_FILE" ]]; then
  printf '\n\n' >> "$STATUS_FILE"
  cat "$TMP_FILE" >> "$STATUS_FILE"
else
  cp "$TMP_FILE" "$STATUS_FILE"
fi

rm -f "$TMP_FILE"
echo "Project status updated in $STATUS_FILE"
