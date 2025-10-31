#!/bin/bash
# Common setup and utility functions for test cases.
if [ -n "${COMMON_SH_SOURCED-}" ]; then
  return
fi
COMMON_SH_SOURCED=1
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/.devcontainer/docker-compose.yml"
DEV_CONTAINER_NAME="devcontainer"
PRIMARY_NAME="mysql-primary"
REPLICA_NAME="mysql-replica"

cleanup_done=0

cleanup() {
  if [ "${cleanup_done}" -eq 1 ]; then
    return
  fi
  cleanup_done=1
  echo "Cleaning up containers..."
  cd "${ROOT_DIR}" || return
  if [ -x "${ROOT_DIR}/cleanup.sh" ]; then
    "${ROOT_DIR}/cleanup.sh" >/dev/null 2>&1 || true
  fi
}

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

wait_for_ssh() {
  local name=$1
  for _ in {1..30}; do
    if docker exec "${DEV_CONTAINER_NAME}" ssh -o BatchMode=yes -o ConnectTimeout=1 "${name}" 'echo "SSH OK"' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "SSH on ${name} did not become ready" >&2
  return 1
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

wait_for_container "${DEV_CONTAINER_NAME}"
wait_for_container "${PRIMARY_NAME}"
wait_for_container "${REPLICA_NAME}"

wait_for_mysql "${PRIMARY_NAME}"
wait_for_mysql "${REPLICA_NAME}"

# Seed the databases and refresh SSH assets.
docker exec "${DEV_CONTAINER_NAME}" bash /workspace/.devcontainer/scripts/post-create.sh

# Ensure SSH client config is fresh inside the devcontainer.
docker exec "${DEV_CONTAINER_NAME}" bash -lc 'rm -f ~/.ssh/known_hosts && /workspace/.devcontainer/scripts/setup-ssh-client.sh'

# Restart containers to ensure SSH keys are loaded.
docker compose -f "${COMPOSE_FILE}" restart "${PRIMARY_NAME}" "${REPLICA_NAME}"

# Wait for containers to be ready again
wait_for_mysql "${PRIMARY_NAME}"
wait_for_mysql "${REPLICA_NAME}"

# Re-run the setup to re-establish replication
docker exec "${DEV_CONTAINER_NAME}" bash /workspace/.devcontainer/mysql/setup-db.sh

# Wait for SSH to be ready.
wait_for_ssh "${PRIMARY_NAME}"
wait_for_ssh "${REPLICA_NAME}"
