#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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
