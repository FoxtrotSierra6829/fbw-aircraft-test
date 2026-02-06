#!/usr/bin/env bash
set -euo pipefail

LOCK="${1:-locks/test/.lock}"   # Use first argument, default if not provided
OWNER="${GITHUB_RUN_ID}-${GITHUB_JOB}"

echo "🔓 Attempting to release lock at '$LOCK'..."

# Only delete the lock if this job owns it
if rclone cat r2:$LOCK | grep -q "^$OWNER "; then
    rclone delete r2:$LOCK || true
    echo "✅ Lock released"
else
    echo "⚠️ Lock not owned by this job, skipping release"
fi
