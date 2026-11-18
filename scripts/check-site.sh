#!/usr/bin/env bash

set -Eeuo pipefail

SITE_DIR="${1:-site}"

echo "Checking website files..."

if [ ! -d "$SITE_DIR" ]; then
    echo "ERROR: Website directory not found."
    exit 1
fi

if [ ! -f "$SITE_DIR/index.html" ]; then
    echo "ERROR: index.html is missing."
    exit 1
fi

if [ ! -s "$SITE_DIR/index.html" ]; then
    echo "ERROR: index.html is empty."
    exit 1
fi

echo "Website checks passed successfully."
