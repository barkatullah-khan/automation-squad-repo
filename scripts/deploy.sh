
#!/usr/bin/env bash

set -Eeuo pipefail

# Deployment directories
BASE="/opt/automation-squad"
STAGING="$BASE/upload"
LIVE_SITE="$BASE/site"
SCRIPTS="$BASE/scripts"
BACKUPS="$BASE/backups"
LOGS="$BASE/logs"

# Deployment information from GitHub Actions
COMMIT="${DEPLOY_COMMIT:?Missing deployment commit}"
ACTOR="${DEPLOY_ACTOR:-unknown}"
DEPLOYED_AT="${DEPLOY_TIME:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S")
BACKUP="$BACKUPS/site-$TIMESTAMP.tar.gz"

echo "Starting website deployment..."
echo "Commit: $COMMIT"
echo "Deployed by: $ACTOR"

# Check uploaded website files
if [ ! -f "$STAGING/site/index.html" ]; then
    echo "ERROR: Website index.html is missing."
    exit 1
fi

# Create required directories
mkdir -p "$BACKUPS" "$LOGS" "$SCRIPTS"

# Back up the existing website
echo "Creating website backup..."

tar -czf "$BACKUP" -C "$BASE" site

echo "Backup created: $BACKUP"

# Update deployment scripts
if [ -d "$STAGING/scripts" ]; then
    rsync -a "$STAGING/scripts/" "$SCRIPTS/"
fi

# Deploy the new website
echo "Deploying website..."

if ! rsync -a --delete \
    "$STAGING/site/" \
    "$LIVE_SITE/"; then

    echo "ERROR: Deployment failed. Restoring previous website..."

    rm -rf "$LIVE_SITE"
    tar -xzf "$BACKUP" -C "$BASE"

    echo "Previous website restored."
    exit 1
fi

# Create deployment information
cat > "$LIVE_SITE/deployment-info.txt" <<EOF
Commit: $COMMIT
Deployed by: $ACTOR
Deployment time: $DEPLOYED_AT
EOF

echo "Deployment completed successfully."
echo "Backup: $BACKUP"
echo "Commit: $COMMIT"
