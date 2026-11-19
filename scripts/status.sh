#!/usr/bin/env bash

set -Eeuo pipefail

# Locate script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$SCRIPT_DIR/team.conf"

# Create live directory
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
if [ -L "$CURRENT_DIR" ]; then
    RELEASE_VALUE="$(readlink -f "$CURRENT_DIR")"
else
    RELEASE_VALUE="$CURRENT_DIR"
fi

# Check warnings
WARNING="No warnings"

if (( DISK_PERCENT >= DISK_WARNING_THRESHOLD )); then
    WARNING="Warning: Disk usage is above ${DISK_WARNING_THRESHOLD}%"
fi

if [ "$NGINX_STATUS" != "Running" ]; then
    WARNING="${WARNING}. Nginx is not running."
fi

# Get latest five deployment entries
if [ -f "$DEPLOY_LOG" ]; then
    DEPLOY_HISTORY="$(tail -n 5 "$DEPLOY_LOG")"
else
    DEPLOY_HISTORY="No deployment log found."
fi

# Escape values before inserting them into HTML
html_escape() {
    local value="$1"
    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    value="${value//\"/&quot;}"
    value="${value//\'/&#39;}"
    printf '%s' "$value"
}

TEAM_NAME_HTML="$(html_escape "$TEAM_NAME")"
HOSTNAME_HTML="$(html_escape "$HOSTNAME_VALUE")"
GENERATED_AT_HTML="$(html_escape "$GENERATED_AT")"
UPTIME_HTML="$(html_escape "$UPTIME_VALUE")"
LOAD_HTML="$(html_escape "$LOAD_VALUE")"
MEMORY_HTML="$(html_escape "$MEMORY_VALUE")"
DISK_HTML="$(html_escape "$DISK_VALUE")"
NGINX_HTML="$(html_escape "$NGINX_STATUS")"
RELEASE_HTML="$(html_escape "$RELEASE_VALUE")"
WARNING_HTML="$(html_escape "$WARNING")"
DEPLOY_HISTORY_HTML="$(html_escape "$DEPLOY_HISTORY")"

# Generate status HTML
cat > "$STATUS_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="60">
    <title>${TEAM_NAME_HTML} - Live Server Status</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f3f4f6;
            margin: 0;
            padding: 30px;
            color: #1f2937;
        }

        .container {
            max-width: 900px;
            margin: auto;
        }

        h1 {
            color: #1d4ed8;
        }

        .card {
            background: white;
            padding: 20px;
            margin: 15px 0;
            border-radius: 10px;
            box-shadow: 0 2px 8px #00000012;
        }

        .warning {
            color: #b45309;
            font-weight: bold;
        }

        .success {
            color: #15803d;
            font-weight: bold;
        }

        pre {
            white-space: pre-wrap;
            overflow-wrap: anywhere;
        }
    </style>
</head>

<body>
<div class="container">

    <h1>${TEAM_NAME_HTML} - Live Server Status</h1>

    <p>Last updated: ${GENERATED_AT_HTML}</p>

    <div class="card">
        <h2>Server Information</h2>
        <p><strong>Hostname:</strong> ${HOSTNAME_HTML}</p>
        <p><strong>Uptime:</strong> ${UPTIME_HTML}</p>
        <p><strong>Load Average:</strong> ${LOAD_HTML}</p>
        <p><strong>Memory:</strong> ${MEMORY_HTML}</p>
        <p><strong>Disk Usage:</strong> ${DISK_HTML}</p>
    </div>

    <div class="card">
        <h2>Service Status</h2>
        <p><strong>Nginx:</strong>
            <span class="$([ "$NGINX_STATUS" = "Running" ] && echo success || echo warning)">
                ${NGINX_HTML}
            </span>
        </p>
    </div>

    <div class="card">
        <h2>Deployment Information</h2>
        <p><strong>Current Release:</strong> ${RELEASE_HTML}</p>
        <h3>Latest Five Deployments</h3>
        <pre>${DEPLOY_HISTORY_HTML}</pre>
    </div>

    <div class="card">
        <h2>System Warnings</h2>
        <p class="warning">${WARNING_HTML}</p>
    </div>

    <p>Page automatically refreshes every 60 seconds.</p>

</div>
</body>
</html>
EOF

echo "Status page generated: $STATUS_FILE"
