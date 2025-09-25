# SSH assets for devcontainer MySQL hosts

These files provide a ready-to-use ED25519 key pair so the workspace container can
connect to `mysql-primary` and `mysql-replica` via SSH/SFTP/SSHFS.

- `id_ed25519` is the private key copied into the app container during
  `postCreateCommand` via `.devcontainer/scripts/setup-ssh-client.sh`.
- `authorized_keys` is mounted into each MySQL container and copied into the
  `dev` user's `~/.ssh/authorized_keys` on start.
- `config` adds host aliases so running `ssh mysql-primary` or
  `scp file mysql-replica:/tmp/` works without extra flags.

Replace these with your own keys if you prefer. After updating `authorized_keys`
run `docker compose restart mysql-primary mysql-replica` to pick up the change,
and re-run `.devcontainer/scripts/setup-ssh-client.sh` (or reload the
Dev Container) so the app container copies the new private key/config.
