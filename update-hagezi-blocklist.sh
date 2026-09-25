#!/bin/bash

### Downloads latest blocklist

set -euo pipefail

URL="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/rpz/pro.txt"

BLOCKLIST_DIR="./responsepolicyzone"
CURRENT="${BLOCKLIST_DIR}/hagezi-rpz.txt"
NEW="${BLOCKLIST_DIR}/hagezi-rpz.txt.new"

mkdir -p "$BLOCKLIST_DIR"

echo "Downloading HaGeZi Multi NORMAL..."

curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --retry 3 \
    --output "$NEW" \
    "$URL"

# Don't install an obviously bad/empty download.
if [[ ! -s "$NEW" ]]; then
    echo "ERROR: downloaded blocklist is empty"
    rm -f "$NEW"
    exit 1
fi

# Basic sanity check.
if ! grep -q "SOA" "$NEW"; then
    echo "ERROR: downloaded file does not look like an RPZ file"
    rm -f "$NEW"
    exit 1
fi

# Atomic replacement.
mv "$NEW" "$CURRENT"

echo "HaGeZi updated:"
wc -l "$CURRENT"