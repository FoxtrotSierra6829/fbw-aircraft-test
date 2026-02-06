#!/usr/bin/env bash
set -euo pipefail

RCLONE_REMOTE="cloudflare-r2"
R2_BUCKET="flybywiresim"
LOCK="${1:-locks/test/.lock}"   # Use first argument, default if not provided
OWNER="${GITHUB_RUN_ID}-${GITHUB_JOB}"

echo "🔓 Attempting to release lock at '$LOCK'..."

# Only delete the lock if this job owns it
if rclone cat $RCLONE_REMOTE:$R2_BUCKET/$LOCK | grep -q "^$OWNER "; then
    rclone delete $RCLONE_REMOTE:$R2_BUCKET/$LOCK || true
    echo "✅ Lock released"
else
    echo "⚠️ Lock not owned by this job, skipping release"
fi
