#!/bin/bash
# Basic end-to-end smoke test for the MySQL devcontainer environment.
set -euo pipefail

# Source the common setup script.
# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Verify SSH and supervisorctl access.
docker exec "${DEV_CONTAINER_NAME}" ssh -o BatchMode=yes mysql-primary 'sudo supervisorctl status'
docker exec "${DEV_CONTAINER_NAME}" ssh -o BatchMode=yes mysql-primary 'sudo ls /data/mysql | head'

# Exercise SCP between workspace and replica.
docker exec "${DEV_CONTAINER_NAME}" bash -lc 'echo smoke-test > /tmp/smoke.txt && scp -o BatchMode=yes /tmp/smoke.txt mysql-replica:/tmp/smoke.txt'
docker exec "${REPLICA_NAME}" cat /tmp/smoke.txt | grep -q "smoke-test"

# Confirm replication health report still passes.
docker exec "${DEV_CONTAINER_NAME}" bash /workspace/.devcontainer/mysql/verify-replication.sh | tee /tmp/verify.log
grep -q "✅ Replication OK" /tmp/verify.log

echo "Smoke test completed successfully."
cleanup
