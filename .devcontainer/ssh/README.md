# SSH assets for devcontainer MySQL hosts

The SSH assets that live in this folder are **generated automatically** when the
dev container comes up for the first time. They are intentionally `.gitignore`d
so every clone can produce its own unique credentials.

- `id_ed25519` / `id_ed25519.pub` – created on-demand by
  `.devcontainer/scripts/setup-ssh-client.sh`; the private key never leaves your
  working copy, while the public key is copied into `authorized_keys`.
- `authorized_keys` – mounted into each MySQL container and installed for the
  `dev` user at boot so SSH/SFTP/SSHFS all work out of the box.
- `config` – tracked in Git so aliases (`mysql-primary`, `mysql-replica`) work
  consistently across workspaces.

If you want to rotate the key pair, delete the generated files in this folder
and run `.devcontainer/scripts/setup-ssh-client.sh` (or rebuild the dev
container). The script will mint a fresh ED25519 key pair, sync `authorized_keys`,
and update your SSH client configuration.
