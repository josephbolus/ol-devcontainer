#!/bin/bash
# Copies the repo-provided SSH assets into the workspace user's ~/.ssh directory.
set -euo pipefail

SSH_SOURCE_DIR="/workspace/.devcontainer/ssh"
SSH_TARGET_DIR="${HOME}/.ssh"
KEY_DEST="${SSH_TARGET_DIR}/devcontainer-mysql-ed25519"
CONFIG_DEST="${SSH_TARGET_DIR}/devcontainer-mysql-config"
MAIN_CONFIG="${SSH_TARGET_DIR}/config"

if [ ! -f "${SSH_SOURCE_DIR}/id_ed25519" ]; then
  install -d -m 700 "${SSH_SOURCE_DIR}"
  ssh-keygen -t ed25519 -N "" -C "devcontainer-mysql" -f "${SSH_SOURCE_DIR}/id_ed25519"
  chmod 600 "${SSH_SOURCE_DIR}/id_ed25519"
fi

if [ -f "${SSH_SOURCE_DIR}/id_ed25519.pub" ]; then
  install -m 600 "${SSH_SOURCE_DIR}/id_ed25519.pub" "${SSH_SOURCE_DIR}/authorized_keys"
fi

install -d -m 700 "${SSH_TARGET_DIR}"
install -m 600 "${SSH_SOURCE_DIR}/id_ed25519" "${KEY_DEST}"
install -m 600 "${SSH_SOURCE_DIR}/config" "${CONFIG_DEST}"

# Ensure the main SSH config includes our devcontainer snippet.
if [ ! -f "${MAIN_CONFIG}" ]; then
  printf "Include %s\n" "${CONFIG_DEST}" > "${MAIN_CONFIG}"
  chmod 600 "${MAIN_CONFIG}"
else
  if ! grep -q "${CONFIG_DEST}" "${MAIN_CONFIG}"; then
    printf "\nInclude %s\n" "${CONFIG_DEST}" >> "${MAIN_CONFIG}"
  fi
  chmod 600 "${MAIN_CONFIG}"
fi

echo "SSH client configuration installed for mysql-primary and mysql-replica."
