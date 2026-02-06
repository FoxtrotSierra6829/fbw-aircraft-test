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
    # 1. Does the lock object exist?
    if ! rclone lsjson "$LOCK_PATH" >/dev/null 2>&1; then
        # 2. No → create it
        echo "$OWNER $(date +%s)" | rclone rcat "$LOCK_PATH"
        echo "✅ Lock acquired"
        exit 0
    fi

    # 3. Exists → read it
    CONTENT="$(rclone cat "$LOCK_PATH" 2>/dev/null || true)"
    LOCK_OWNER="$(awk '{print $1}' <<< "$CONTENT")"
    LOCK_TIME="$(awk '{print $2}' <<< "$CONTENT")"

    # 4. If unreadable or malformed → treat as active, do NOT delete
    if ! [[ "$LOCK_TIME" =~ ^[0-9]+$ ]]; then
        echo "🔒 Lock exists but unreadable, waiting..."
    else
        NOW=$(date +%s)
        AGE=$((NOW - LOCK_TIME))

        if (( AGE > STALE )); then
            echo "⚠️ Stale lock (age $AGE s), deleting..."
            rclone delete "$LOCK_PATH" || true
            continue
        else
            echo "🔒 Lock held by $LOCK_OWNER (age $AGE s), waiting..."
        fi
    fi

    if (( $(date +%s) - START > MAX_WAIT )); then
        echo "❌ Timeout waiting for lock"
        exit 1
    fi

    sleep $SLEEP
done
