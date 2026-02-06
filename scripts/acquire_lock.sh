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

LOCK_PATH="$RCLONE_REMOTE:$R2_BUCKET/$LOCK"

echo "🔐 Attempting to acquire lock at '$LOCK_PATH'..."

while true; do
    if ! rclone cat "$LOCK_PATH" >/dev/null 2>&1; then
        # Lock doesn't exist, create it
        echo "$OWNER $(date +%s)" | rclone rcat "$LOCK_PATH"
        echo "✅ Lock acquired"
        break
    else
        # Lock exists, check if stale
        CONTENT=$(rclone cat "$LOCK_PATH")
        LOCK_TIME=$(awk '{print $2}' <<< "$CONTENT")
        NOW=$(date +%s)
        AGE=$((NOW - LOCK_TIME))

        if (( AGE > STALE )); then
            echo "⚠️ Stale lock detected (age: $AGE s), deleting..."
            rclone delete "$LOCK_PATH" || true
            continue
        else
            LOCK_OWNER=$(awk '{print $1}' <<< "$CONTENT")
            echo "🔒 Lock held by $LOCK_OWNER (age: $AGE s), waiting..."
        fi
    fi

    if (( $(date +%s) - START > MAX_WAIT )); then
        echo "❌ Timeout waiting for lock"
        exit 1
    fi

    sleep $SLEEP
done
