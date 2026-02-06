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
TMP="$(mktemp)"

echo "$OWNER $(date +%s)" > "$TMP"

echo "🔐 Attempting to acquire lock at '$LOCK_PATH'..."

while true; do
    # ATOMIC attempt
    if rclone copy "$TMP" "$LOCK_PATH" --ignore-existing >/dev/null 2>&1; then
        echo "✅ Lock acquired"
        break
    fi

    # Lock exists → read it
    CONTENT="$(rclone cat "$LOCK_PATH" 2>/dev/null || true)"
    LOCK_OWNER="$(awk '{print $1}' <<< "$CONTENT")"
    LOCK_TIME="$(awk '{print $2}' <<< "$CONTENT")"

    if ! [[ "$LOCK_TIME" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Lock corrupted, deleting..."
        rclone delete "$LOCK_PATH" || true
        continue
    fi

    NOW=$(date +%s)
    AGE=$((NOW - LOCK_TIME))

    if (( AGE > STALE )); then
        echo "⚠️ Stale lock (age $AGE s), deleting..."
        rclone delete "$LOCK_PATH" || true
    else
        echo "🔒 Lock held by $LOCK_OWNER (age $AGE s), waiting..."
    fi

    if (( NOW - START > MAX_WAIT )); then
        echo "❌ Timeout waiting for lock"
        exit 1
    fi

    sleep $SLEEP
done

rm -f "$TMP"
