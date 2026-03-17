#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$HOME/projects/mess_cafe_automation_v1/project_state"
STATUS_FILE="${1:-$BASE_DIR/project_command_board_status.md}"
STAMP="$(date '+%d-%b-%Y %H:%M')"

cat >> "$STATUS_FILE" <<EOF

----------------------------------------------------------
## Update Entry - ${STAMP}

### Completed
- [to be filled]

### Ongoing
- [to be filled]

### Next
- [to be filled]

### Decisions / Risks
- [to be filled]

EOF

echo "Project status updated in $STATUS_FILE"
