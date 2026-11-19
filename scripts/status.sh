
#!/usr/bin/env bash

set -Eeuo pipefail

# Find the directory containing this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Load team configuration
source "$SCRIPT_DIR/team.conf"

# Create the live directory if it does not exist
mkdir -p "$LIVE_DIR"

# Collect server information
HOSTNAME_VALUE="$(hostname)"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
UPTIME_VALUE="$(uptime -p 2>/dev/null || uptime)"
LOAD_VALUE="$(uptime | awk -F'load average:' '{print $2}' | xargs)"
MEMORY_VALUE="$(free -h | awk '/^Mem:/ {print $3 " used / " $2 " total"}')"

# Get disk usage percentage
DISK_VALUE="$(df -P "$BASE_DIR" | awk 'NR==2 {print $5}')"
DISK_PERCENT="${DISK_VALUE%\%}"

# Check Nginx status
if systemctl is-active --quiet nginx; then
    NGINX_STATUS="Running"
    NGINX_CLASS="success"
else
    NGINX_STATUS="Not running"
    NGINX_CLASS="warning"
fi

# Identify the current release
if [ -L "$CURRENT_DIR" ]; then
    RELEASE_VALUE="$(readlink -f "$CURRENT_DIR")"
else
    RELEASE_VALUE="$CURRENT_DIR (not a symlink)"
fi

# Check warning conditions
WARNING=""

if (( DISK_PERCENT > DISK_WARNING_THRESHOLD )); then
    WARNING="Disk usage is above ${DISK_WARNING_THRESHOLD}%."
fi

if [ "$NGINX_STATUS" != "Running" ]; then
    WARNING="${WARNING} Nginx is not running."
fi

# Read the latest five deployment log entries
if [ -f "$DEPLOY_LOG" ]; then
    DEPLOY_HISTORY="$(tail -n 5 "$DEPLOY_LOG")"
else
    DEPLOY_HISTORY="No deployment log found."
fi

# Generate the status webpage
{
    cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${TEAM_NAME} Server Status</title>
<style>
body {
    font-family: Arial, sans-serif;
    background: #f4f6f9;
    color: #222;
    margin: 0;
    padding: 30px;
}
.container {
    max-width: 850px;
    margin: auto;
    background: white;
    padding: 25px;
    border-radius: 12px;
    box-shadow: 0 3px 12px rgba(0,0,0,0.08);
}
h1 { color: #2457a6; }
.item {
    padding: 12px;
    border-bottom: 1px solid #eee;
}
.success { color: green; font-weight: bold; }
.warning {
    color: #b00020;
    background: #ffe5e5;
    padding: 12px;
    border-radius: 6px;
    font-weight: bold;
}
pre {
    background: #f1f3f5;
    padding: 15px;
    border-radius: 6px;
    white-space: pre-wrap;
}
</style>
</head>
<body>
<div class="container">
<h1>${TEAM_NAME} - Server Status</h1>
<p>Generated: ${GENERATED_AT}</p>

EOF

    if [ -n "$WARNING" ]; then
        printf '<div class="warning">WARNING: %s</div>\n' "$WARNING"
    else
        printf '<div class="success">All systems operational</div>\n'
    fi

    cat <<EOF
<h2>Server Information</h2>
<div class="item"><strong>Hostname:</strong> ${HOSTNAME_VALUE}</div>
<div class="item"><strong>Uptime:</strong> ${UPTIME_VALUE}</div>
<div class="item"><strong>Load Average:</strong> ${LOAD_VALUE}</div>
<div class="item"><strong>Memory:</strong> ${MEMORY_VALUE}</div>
<div class="item"><strong>Disk Usage:</strong> ${DISK_VALUE}</div>
<div class="item"><strong>Nginx:</strong> <span class="${NGINX_CLASS}">${NGINX_STATUS}</span></div>
<div class="item"><strong>Current Release:</strong> ${RELEASE_VALUE}</div>

<h2>Last Five Deployments</h2>
<pre>
EOF

    printf '%s\n' "$DEPLOY_HISTORY"

    cat <<EOF
</pre>
</div>
</body>
</html>
EOF

} > "$STATUS_FILE"

echo "Status page generated: $STATUS_FILE"
