#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUS_FILE="${1:-$BASE_DIR/project_command_board_status.md}"
STAMP="$(date '+%d-%b-%Y %H:%M')"

echo "Project status updater"
echo "Status file: $STATUS_FILE"
echo

read -rp "Completed today: " COMPLETED
read -rp "Currently ongoing: " ONGOING
read -rp "Next step: " NEXT_STEP
read -rp "Decisions / risks: " RISKS

cat >> "$STATUS_FILE" <<EOF

----------------------------------------------------------
## Update Entry - ${STAMP}

### Completed
- ${COMPLETED:-[not provided]}

### Ongoing
- ${ONGOING:-[not provided]}

### Next
- ${NEXT_STEP:-[not provided]}

### Decisions / Risks
- ${RISKS:-[not provided]}

EOF

echo "Project status updated in $STATUS_FILE"
