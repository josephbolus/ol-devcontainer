#!/bin/bash
set -euo pipefail

/workspace/.devcontainer/scripts/setup-ssh-client.sh
bash /workspace/.devcontainer/mysql/setup-db.sh
