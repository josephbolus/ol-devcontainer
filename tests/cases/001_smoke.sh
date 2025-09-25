#!/bin/bash
# Basic end-to-end smoke test for the MySQL devcontainer environment.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/.devcontainer/docker-compose.yml"
DEV_CONTAINER_NAME="devcontainer"
PRIMARY_NAME="mysql-primary"
REPLICA_NAME="mysql-replica"

cleanup() {
  cd "${ROOT_DIR}" || return
  if [ -x "${ROOT_DIR}/cleanup.sh" ]; then
    "${ROOT_DIR}/cleanup.sh" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

cd "${ROOT_DIR}"
cleanup

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run tests." >&2
  exit 1
fi

export COMPOSE_DOCKER_CLI_BUILD=1

docker compose -f "${COMPOSE_FILE}" build

docker compose -f "${COMPOSE_FILE}" up -d

wait_for_container() {
  local name=$1
  for _ in {1..30}; do
    if docker ps --filter "name=^${name}$" --filter "status=running" --format '{{.Names}}' | grep -qx "${name}"; then
      return 0
    fi
    sleep 2
  done
  echo "Container ${name} did not start" >&2
  docker ps -a
  return 1
}

wait_for_mysql() {
  local name=$1
  for _ in {1..60}; do
    if docker exec "${name}" mysqladmin --protocol=socket --socket=/data/mysql/mysql.sock -uroot -prootpassword ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "MySQL ${name} did not become ready" >&2
  docker logs "${name}" || true
  return 1
}

wait_for_container "${DEV_CONTAINER_NAME}"
wait_for_container "${PRIMARY_NAME}"
wait_for_container "${REPLICA_NAME}"

# Seed the databases and refresh SSH assets.
docker exec "${DEV_CONTAINER_NAME}" bash /workspace/.devcontainer/scripts/post-create.sh

wait_for_mysql "${PRIMARY_NAME}"
wait_for_mysql "${REPLICA_NAME}"

# Ensure SSH client config is fresh inside the devcontainer.
docker exec "${DEV_CONTAINER_NAME}" bash -lc 'rm -f ~/.ssh/known_hosts && /workspace/.devcontainer/scripts/setup-ssh-client.sh'

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
