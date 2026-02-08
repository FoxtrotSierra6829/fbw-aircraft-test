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
LOCK_PATH="$RCLONE_REMOTE:$R2_BUCKET/$LOCK"

echo "🔐 Attempting to acquire lock at '$LOCK_PATH'..."

while true; do
    # LIST DIRECTORY CONTENTS AND CHECK FOR FILE NAME
    if ! rclone ls "$DIR_PATH" 2>/dev/null | awk '{print $2}' | grep -Fxq "$FILE"; then
        # FILE DOES NOT EXIST → CREATE IT
        echo "$OWNER $(date +%s)" > /tmp/lockfile
        rclone copyto /tmp/lockfile "$LOCK_PATH"
        echo "✅ Lock acquired"
        exit 0
    fi

    # FILE EXISTS → READ IT
    CONTENT="$(rclone cat "$LOCK_PATH" 2>/dev/null || true)"
    LOCK_TIME="$(awk '{print $2}' <<< "$CONTENT")"

    if [[ "$LOCK_TIME" =~ ^[0-9]+$ ]]; then
        NOW=$(date +%s)
        AGE=$((NOW - LOCK_TIME))

        if (( AGE > STALE )); then
            echo "⚠️ Stale lock (age $AGE s), deleting..."
            rclone delete "$LOCK_PATH" || true
            continue
        fi
    fi

    echo "🔒 Lock exists, waiting..."

    if (( $(date +%s) - START > MAX_WAIT )); then
        echo "❌ Timeout waiting for lock"
        exit 1
    fi

    sleep $SLEEP
done
