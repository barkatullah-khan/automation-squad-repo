
#!/usr/bin/env bash

set -Eeuo pipefail

# Locate script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Load project configuration
source "$SCRIPT_DIR/team.conf"

# Locate HTML template
TEMPLATE_FILE="$SCRIPT_DIR/traffic-template.html"

# Check template
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "ERROR: Traffic template not found: $TEMPLATE_FILE" >&2
    exit 1
fi

# Check access log
if [[ ! -r "$NGINX_ACCESS_LOG" ]]; then
    echo "ERROR: Cannot read Nginx access log: $NGINX_ACCESS_LOG" >&2
    exit 1
fi

# Create live directory
mkdir -p "$LIVE_DIR"

# Generate traffic report using Python
python3 - "$NGINX_ACCESS_LOG" "$TEMPLATE_FILE" "$REPORT_FILE" "$TEAM_NAME" <<'PY'
import sys
import re
import html
from pathlib import Path
from collections import Counter
from urllib.parse import urlsplit
from datetime import datetime, timezone

# Receive file paths and team name
log_file = Path(sys.argv[1])
template_file = Path(sys.argv[2])
report_file = Path(sys.argv[3])
team_name = sys.argv[4]

# Read HTML template
template = template_file.read_text(encoding="utf-8")

# Counters for traffic statistics
total_requests = 0
not_found = 0

pages = Counter()
visitors = Counter()
missing_pages = Counter()

# Match standard Nginx combined access log entries
pattern = re.compile(
    r'^(\S+) \S+ \S+ \[[^\]]+\] "(\S+) (.*?) HTTP/[^"]+" (\d{3})'
)

# Read and process access log
with log_file.open("r", encoding="utf-8", errors="replace") as log:

    for line in log:

        match = pattern.match(line)

        if not match:
            continue

        ip, method, request_url, status = match.groups()

        # Extract URL path and remove query strings
        path = urlsplit(request_url).path

        # Exclude live status and report requests
        if path == "/live" or path.startswith("/live/"):
            continue

        status = int(status)

        # Count requests and visitors
        total_requests += 1
        visitors[ip] += 1
        pages[path] += 1

        # Count 404 responses
        if status == 404:
            not_found += 1
            missing_pages[path] += 1


# Safely escape dynamic HTML values
def escape(value):
    return html.escape(str(value))


# Generate HTML table rows
def generate_rows(counter):

    if not counter:
        return '<tr><td colspan="2" class="empty">No data available</td></tr>'

    rows = []

    for name, count in counter.most_common(5):

        rows.append(
            f"<tr><td>{escape(name)}</td><td>{count}</td></tr>"
        )

    return "\n".join(rows)


# Prepare template values
generated_at = datetime.now(timezone.utc).strftime(
    "%Y-%m-%d %H:%M:%S UTC"
)

values = {
    "{{TEAM_NAME}}": escape(team_name),
    "{{GENERATED_AT}}": escape(generated_at),
    "{{TOTAL_REQUESTS}}": str(total_requests),
    "{{NOT_FOUND}}": str(not_found),
    "{{TOP_PAGES}}": generate_rows(pages),
    "{{TOP_VISITORS}}": generate_rows(visitors),
    "{{TOP_MISSING}}": generate_rows(missing_pages),
}

# Replace placeholders in HTML template
for placeholder, value in values.items():
    template = template.replace(placeholder, value)

# Write final HTML report
report_file.write_text(template, encoding="utf-8")

print(f"Traffic report generated successfully: {report_file}")
print(f"Total requests: {total_requests}")
print(f"404 responses: {not_found}")
PY
