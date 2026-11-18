#!/usr/bin/env bash

set -Eeuo pipefail

BASE="/opt/automation-squad"
LIVE_SITE="$BASE/site"
BACKUPS="$BASE/backups"
LOGS="$BASE/logs"

echo "Starting website rollback..."

# Find the latest backup
LATEST_BACKUP=$(find "$BACKUPS" -maxdepth 1 -type f \
    -name 'site-*.tar.gz' -printf '%T@ %p\n' |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-)

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No website backup found."
    exit 1
fi

echo "Using backup: $LATEST_BACKUP"

# Restore the previous website
TEMP_DIR=$(mktemp -d)

tar -xzf "$LATEST_BACKUP" -C "$TEMP_DIR"

if [ ! -f "$TEMP_DIR/site/index.html" ]; then
    echo "ERROR: Backup does not contain index.html."
    rm -rf "$TEMP_DIR"
    exit 1
fi

rsync -a --delete "$TEMP_DIR/site/" "$LIVE_SITE/"

rm -rf "$TEMP_DIR"

echo "Rollback completed successfully."
