#!/bin/bash
# Quick locking verification test
# Runs background sync, tests login speed, checks logs

echo "=== Quick Locking Test ==="

# 1. Start background sync
echo "Starting background sync..."
./tests/test-concurrent-sync.sh &
BG_PID=$!
sleep 2

# 2. Test login (should be fast)
echo "Testing login during sync..."
echo "(Expecting < 5 seconds)"
time curl -s -u admin:admin http://stable31.local/index.php/apps/files/ > /dev/null

# 3. Test manual sync (should coordinate)
echo -e "\nTesting manual sync during background sync..."
curl -s -u admin:admin -X POST \
  http://stable31.local/index.php/apps/user_vo/admin/sync-all-groups \
  -H "OCS-APIRequest: true" | jq -r '.message // .error // "Unknown response"'

# 4. Stop background sync
echo -e "\nStopping background sync..."
kill $BG_PID 2>/dev/null
wait $BG_PID 2>/dev/null

# 5. Check logs
echo -e "\nChecking logs for lock messages..."
docker compose exec -u 33 stable31 grep "Skipping group sync\|Lock acquired" \
  /var/www/html/data/nextcloud.log 2>/dev/null | tail -10

echo -e "\n=== Test Complete ==="
