#!/usr/bin/env bash
set -euo pipefail

RCLONE_REMOTE="cloudflare-r2"
R2_BUCKET="flybywiresim"
LOCK="${1:-locks/test/.lock}"

OWNER="${GITHUB_RUN_ID:-local}-${GITHUB_JOB:-local}"
MAX_WAIT=1800
STALE=3600
SLEEP=10
START=$(date +%s)

DIR="$(dirname "$LOCK")"
FILE="$(basename "$LOCK")"
DIR_PATH="$RCLONE_REMOTE:$R2_BUCKET/$DIR"
LOCK_PATH="$DIR_PATH/$FILE"

echo "🔐 Attempting to acquire lock at '$LOCK_PATH'..."

while true; do
    # 1. LIST DIRECTORY CONTENTS
    if ! rclone lsjson "$DIR_PATH" | jq -e ".[] | select(.Name == \"$FILE\")" >/dev/null; then
        # 2. FILE NOT PRESENT → CREATE
        echo "$OWNER $(date +%s)" | rclone rcat "$LOCK_PATH"
        echo "✅ Lock acquired"
        exit 0
    fi

    # 3. FILE PRESENT → READ IT
    CONTENT="$(rclone cat "$LOCK_PATH" 2>/dev/null || true)"
    LOCK_OWNER="$(awk '{print $1}' <<< "$CONTENT")"
    LOCK_TIME="$(awk '{print $2}' <<< "$CONTENT")"

    # 4. IF TIMESTAMP VALID → CHECK STALE
    if [[ "$LOCK_TIME" =~ ^[0-9]+$ ]]; then
        NOW=$(date +%s)
        AGE=$((NOW - LOCK_TIME))

        if (( AGE > STALE )); then
            echo "⚠️ Stale lock (age $AGE s), deleting..."
            rclone delete "$LOCK_PATH" || true
            continue
        fi

        echo "🔒 Lock held by $LOCK_OWNER (age $AGE s), waiting..."
    else
        # 5. FILE EXISTS BUT CONTENT BAD → TREAT AS ACTIVE
        echo "🔒 Lock exists, waiting..."
    fi

    if (( $(date +%s) - START > MAX_WAIT )); then
        echo "❌ Timeout waiting for lock"
        exit 1
    fi

    sleep $SLEEP
done
