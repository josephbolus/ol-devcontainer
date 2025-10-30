#!/bin/bash
# Test case for SSH aliases.
set -euo pipefail

# Source the common setup script.
# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Verify SSH aliases.
docker exec "${DEV_CONTAINER_NAME}" ssh -o BatchMode=yes dbprimary 'echo "Hello from dbprimary"'
docker exec "${DEV_CONTAINER_NAME}" ssh -o BatchMode=yes dbreplica 'echo "Hello from dbreplica"'

echo "SSH alias test completed successfully."
cleanup
