#!/bin/bash
# Container entrypoint that bootstraps the MySQL datadir (if needed) and then execs supervisord.
set -euo pipefail

MYSQL_DATADIR=${MYSQL_DATADIR:-/data/mysql}
MYSQL_SOCKET=${MYSQL_SOCKET:-/data/mysql/mysql.sock}
MYSQLX_SOCKET=${MYSQLX_SOCKET:-/data/mysql/mysqlx.sock}
MYSQL_LOG_ERROR=${MYSQL_LOG_ERROR:-/var/log/mysqld.log}
INIT_DIR="/docker-entrypoint-initdb.d"
DEFAULTS_FILE=${MYSQL_DEFAULTS_FILE:-/etc/my.cnf}
SSH_SOURCE_DIR=${SSH_SOURCE_DIR:-/opt/devcontainer/ssh}
SSH_USER=${SSH_USER:-dev}

ensure_dirs() {
  mkdir -p "${MYSQL_DATADIR}" "$(dirname "${MYSQL_SOCKET}")" "$(dirname "${MYSQLX_SOCKET}")" /var/run/mysqld
  chown -R mysql:mysql "${MYSQL_DATADIR}" /var/run/mysqld
  chmod 750 "${MYSQL_DATADIR}"
  touch "${MYSQL_LOG_ERROR}"
  chown mysql:mysql "${MYSQL_LOG_ERROR}"
}

setup_sshd() {
  mkdir -p /var/run/sshd
  chmod 755 /var/run/sshd
  ssh-keygen -A >/dev/null 2>&1

  local passwd_entry
  passwd_entry=$(getent passwd "${SSH_USER}" || true)
  if [ -z "${passwd_entry}" ]; then
    echo "Warning: SSH user ${SSH_USER} not found; skipping authorized key setup." >&2
    return
  fi

  local ssh_home
  ssh_home=$(echo "${passwd_entry}" | cut -d: -f6)
  local ssh_dir="${ssh_home}/.ssh"
  mkdir -p "${ssh_dir}"
  chmod 700 "${ssh_dir}"
  chown "${SSH_USER}:${SSH_USER}" "${ssh_dir}"

  if [ -d "${SSH_SOURCE_DIR}" ] && [ -f "${SSH_SOURCE_DIR}/authorized_keys" ]; then
    cp "${SSH_SOURCE_DIR}/authorized_keys" "${ssh_dir}/authorized_keys"
    chown "${SSH_USER}:${SSH_USER}" "${ssh_dir}/authorized_keys"
    chmod 600 "${ssh_dir}/authorized_keys"
  fi
}

run_mysqld_temp() {
  local extra_args=("$@")
  /usr/sbin/mysqld --defaults-file="${DEFAULTS_FILE}" \
    --datadir="${MYSQL_DATADIR}" \
    --socket="${MYSQL_SOCKET}" \
    --mysqlx-socket="${MYSQLX_SOCKET}" \
    --user=mysql \
    "${extra_args[@]}" &
  echo $!
}

mysql_wait_until_ready() {
  local mysql_args=(--protocol=socket --socket="${MYSQL_SOCKET}" --user=root)
  for i in {60..0}; do
    if mysqladmin "${mysql_args[@]}" ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "MySQL init process failed: server did not start." >&2
  return 1
}

process_init_files() {
  if [ ! -d "${INIT_DIR}" ]; then
    return
  fi
  echo "Running init scripts in ${INIT_DIR}"
  local f
  for f in "${INIT_DIR}"/*; do
    [ -e "$f" ] || continue
    case "$f" in
      *.sh)
        echo "Running $f"
        MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-}" MYSQL_SOCKET="${MYSQL_SOCKET}" bash "$f"
        ;;
      *.sql)
        echo "Importing $f"
        MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-}" mysql --protocol=socket --socket="${MYSQL_SOCKET}" --user=root <"$f"
        ;;
      *.sql.gz)
        echo "Importing $f"
        gunzip -c "$f" | MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-}" mysql --protocol=socket --socket="${MYSQL_SOCKET}" --user=root
        ;;
      *)
        echo "Ignoring $f"
        ;;
    esac
  done
}

main() {
  ensure_dirs
  setup_sshd

  if [ ! -d "${MYSQL_DATADIR}/mysql" ]; then
    echo "Initializing MySQL datadir at ${MYSQL_DATADIR}"
    /usr/sbin/mysqld --defaults-file="${DEFAULTS_FILE}" --initialize-insecure --user=mysql --datadir="${MYSQL_DATADIR}" --log-error="${MYSQL_LOG_ERROR}"

    local mysqld_pid
    mysqld_pid=$(run_mysqld_temp --skip-networking)
    mysql_wait_until_ready

    local mysql_cmd=(mysql --protocol=socket --socket="${MYSQL_SOCKET}" --user=root)

    if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
      "${mysql_cmd[@]}" <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE USER IF NOT EXISTS 'root'@'${MYSQL_ROOT_HOST:-%}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'${MYSQL_ROOT_HOST:-%}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOSQL
      mysql_cmd+=(--password="${MYSQL_ROOT_PASSWORD}")
    else
      mysql_cmd+=(--password="")
    fi

    local grant_target="*.*"
    if [ -n "${MYSQL_DATABASE:-}" ]; then
      "${mysql_cmd[@]}" <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
EOSQL
      grant_target="\`${MYSQL_DATABASE}\`.*"
    fi

    if [ -n "${MYSQL_USER:-}" ] && [ -n "${MYSQL_PASSWORD:-}" ]; then
      "${mysql_cmd[@]}" <<EOSQL
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${grant_target} TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL
    fi

    export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-}"
    process_init_files
    unset MYSQL_PWD

    if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
      mysqladmin --protocol=socket --socket="${MYSQL_SOCKET}" --user=root --password="${MYSQL_ROOT_PASSWORD}" shutdown
    else
      mysqladmin --protocol=socket --socket="${MYSQL_SOCKET}" --user=root shutdown
    fi
    wait "${mysqld_pid}"
  fi

  chown -R mysql:mysql "${MYSQL_DATADIR}"

  exec "$@"
}

main "$@"
