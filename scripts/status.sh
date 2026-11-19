
#!/usr/bin/env bash

set -Eeuo pipefail

# Locate the script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$SCRIPT_DIR/team.conf"

# Locate the HTML template
TEMPLATE_FILE="$SCRIPT_DIR/status-template.html"

# Check that the template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "ERROR: Status template not found: $TEMPLATE_FILE" >&2
    exit 1
fi

# Create the live directory
mkdir -p "$LIVE_DIR"

# Collect server information
HOSTNAME_VALUE="$(hostname)"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
UPTIME_VALUE="$(uptime -p 2>/dev/null || uptime)"
LOAD_VALUE="$(awk '{print $1 ", " $2 ", " $3}' /proc/loadavg)"
MEMORY_VALUE="$(free -h | awk '/^Mem:/ {print $3 " used / " $2 " total"}')"

# Collect disk usage
DISK_VALUE="$(df -P "$BASE_DIR" | awk 'NR==2 {print $5}')"
DISK_PERCENT="${DISK_VALUE%\%}"

# Check Nginx status
if systemctl is-active --quiet nginx; then
    NGINX_STATUS="Running"
else
    NGINX_STATUS="Not running"
fi

# Identify current release
if [[ -L "$CURRENT_DIR" ]]; then
    RELEASE_VALUE="$(readlink -f "$CURRENT_DIR")"
else
    RELEASE_VALUE="$CURRENT_DIR"
fi

# Check system warnings
WARNING="No warnings"

if (( DISK_PERCENT >= DISK_WARNING_THRESHOLD )); then
    WARNING="Warning: Disk usage is above ${DISK_WARNING_THRESHOLD}%"
fi

if [[ "$NGINX_STATUS" != "Running" ]]; then
    if [[ "$WARNING" == "No warnings" ]]; then
        WARNING="Nginx is not running."
    else
        WARNING="${WARNING}. Nginx is not running."
    fi
fi

# Determine overall system status
if [[ "$WARNING" == "No warnings" ]]; then
    OVERALL_STATUS="Operational"
else
    OVERALL_STATUS="Attention Required"
fi

# Get latest five deployment entries
if [[ -f "$DEPLOY_LOG" ]]; then
    DEPLOY_HISTORY="$(tail -n 5 "$DEPLOY_LOG")"
else
    DEPLOY_HISTORY="No deployment log found."
fi

# Export collected values for the HTML renderer
export TEAM_NAME
export HOSTNAME_VALUE
export GENERATED_AT
export UPTIME_VALUE
export LOAD_VALUE
export MEMORY_VALUE
export DISK_VALUE
export NGINX_STATUS
export RELEASE_VALUE
export WARNING
export OVERALL_STATUS
export DEPLOY_HISTORY

# Generate the status HTML from the separate template
python3 - "$TEMPLATE_FILE" "$STATUS_FILE" <<'PY'
import html
import os
import sys
from pathlib import Path

template_file = Path(sys.argv[1])
status_file = Path(sys.argv[2])

template = template_file.read_text(encoding="utf-8")

values = {
    "{{TEAM_NAME}}": os.environ["TEAM_NAME"],
    "{{GENERATED_AT}}": os.environ["GENERATED_AT"],
    "{{OVERALL_STATUS}}": os.environ["OVERALL_STATUS"],
    "{{HOSTNAME}}": os.environ["HOSTNAME_VALUE"],
    "{{UPTIME}}": os.environ["UPTIME_VALUE"],
    "{{LOAD}}": os.environ["LOAD_VALUE"],
    "{{MEMORY}}": os.environ["MEMORY_VALUE"],
    "{{DISK}}": os.environ["DISK_VALUE"],
    "{{NGINX_STATUS}}": os.environ["NGINX_STATUS"],
    "{{RELEASE}}": os.environ["RELEASE_VALUE"],
    "{{WARNING}}": os.environ["WARNING"],
    "{{DEPLOY_HISTORY}}": os.environ["DEPLOY_HISTORY"],
}

for placeholder, value in values.items():
    template = template.replace(placeholder, html.escape(value))

status_file.write_text(template, encoding="utf-8")
PY

echo "Status page generated successfully: $STATUS_FILE"
