#!/bin/bash
# Continuous background sync script for testing lock contention
# Usage: ./test-concurrent-sync.sh &
# Stop: kill $!

echo "Starting continuous background sync..."
echo "Press Ctrl+C to stop"

while true; do
    echo "[$(date)] Triggering sync..."

    # Sync all groups
    curl -s -u admin:admin -X POST \
      http://stable31.local/index.php/apps/user_vo/admin/sync-all-groups \
      -H "OCS-APIRequest: true" | jq -r '.summary // .message // "Error"'

    # Wait 5 seconds before next sync
    sleep 5
done
