# Repository Guidelines

## Project Structure & Module Organization
- `.devcontainer/` hosts the VS Code container setup; edit `devcontainer.json` when adding tooling or ports.
- `.devcontainer/Dockerfile` builds the Ubuntu 22.04 base with MySQL Shell and CLI utilities.
- `.devcontainer/conf/primary.cnf` and `replica.cnf` hold server overrides; document every change inline.
- `.devcontainer/mysql/` contains init SQL plus automation scripts; keep new lifecycle scripts beside `setup-db.sh` and `verify-replication.sh`.
- `docs/` stores upstream references that explain configuration decisions.

## Build, Test, and Development Commands
- `docker compose -f .devcontainer/docker-compose.yml up -d` boots the app container with the primary/replica pair.
- `docker compose -f .devcontainer/docker-compose.yml down -v` stops services and wipes state before config refactors.
- `bash .devcontainer/mysql/setup-db.sh` reseeds the cluster; rerun after editing SQL or `.cnf`.
- `bash .devcontainer/mysql/verify-replication.sh` confirms replication and sample-row sync prior to commit.

## Coding Style & Naming Conventions
- Use two-space indentation for JSON, YAML, and shell scripts; keep related blocks grouped.
- Bash scripts remain POSIX-safe Bash with `#!/bin/bash`, `set -e`, quoted expansions, and lower-kebab-case filenames.
- SQL files in `mysql/init-scripts/` use uppercase keywords, lowercase identifiers, and one concern per file.
- Reuse canonical MySQL option names (`server-id`, `binlog_format`) instead of project-specific aliases.

## Testing Guidelines
- Run the verification script after any Docker, SQL, or script edit and paste the "Replication OK" line in PR evidence.
- When diagnosing drift, query the replica with `mysql -h mysql-replica testdb -e "SELECT COUNT(*) FROM sample_data;"`.
- Monitor health via `docker compose logs -f mysql-primary mysql-replica` and clear warnings before merge.
- New automation should mimic `setup-db.sh` idempotency and emit actionable error messages.

## Commit & Pull Request Guidelines
- There is no established history; adopt Conventional Commits (e.g., `fix: adjust replica binlog retention`) to set the baseline.
- Keep each commit scoped to one change and explain tuning rationale in the body if `.cnf` or compose files move.
- PRs need an overview, the exact commands used for validation, links to tracking work, and any relevant log excerpts.

## Environment & Security Tips
- Keep credentials illustrative; store real secrets via local overrides or external secret stores instead of Git.
- Update MySQL image tags or download URLs in tandem with notes in `docs/`, and prefer `forwardPorts` over direct port edits when exposing services.
