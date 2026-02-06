#!/usr/bin/env bash
set -euo pipefail

LOCK="${1:-locks/test/.lock}"   # Use first argument, default if not provided
OWNER="${GITHUB_RUN_ID}-${GITHUB_JOB}"
MAX_WAIT=1800   # 30 minutes
STALE=3600      # 1 hour
SLEEP=10
START=$(date +%s)

echo "🔐 Attempting to acquire lock at '$LOCK'..."

while true; do
    if ! rclone ls r2:$LOCK >/dev/null 2>&1; then
        # Lock doesn't exist, create it
        echo "$OWNER $(date +%s)" | rclone rcat r2:$LOCK
        echo "✅ Lock acquired"
        break
    else
        # Lock exists, check if stale
        LOCK_TIME=$(rclone cat r2:$LOCK | awk '{print $2}')
        NOW=$(date +%s)
        AGE=$((NOW - LOCK_TIME))
        if (( AGE > STALE )); then
            echo "⚠️ Stale lock detected (age: $AGE s), deleting..."
            rclone delete r2:$LOCK || true
            continue
        else
            LOCK_OWNER=$(rclone cat r2:$LOCK | awk '{print $1}')
            echo "🔒 Lock held by $LOCK_OWNER (age: $AGE s), waiting..."
        fi
    fi

    # Timeout check
    if (( $(date +%s) - START > MAX_WAIT )); then
        echo "❌ Timeout waiting for lock"
        exit 1
    fi

    sleep $SLEEP
done
