# AGENTS.md

## What this repo does
- `liftoff` is an Ansible deployment project: `site.yml` runs two roles in order (`docker` then `xtm_deploy`) against `xtm_servers`.
- The end state is a Docker Compose stack at `{{ xtm_deploy_dir }}` (default `/opt/xtm`) with OpenCTI + OpenAEV and their dependencies.

## Architecture and flow (read these together)
- Entry point: `site.yml` -> `roles/docker/tasks/main.yml` -> `roles/xtm_deploy/tasks/main.yml`.
- Config contract: user-editable values live in `group_vars/all.yml`; they are rendered into `roles/xtm_deploy/templates/env.j2`.
- Runtime graph: `roles/xtm_deploy/files/docker-compose.yml` defines infra (`redis`, `elasticsearch`, `pgsql`, `minio`, `rabbitmq`) plus apps (`opencti`, `openaev`), workers, connectors, collectors, injectors.
- Cross-service trust uses tokens/IDs from `.env`; for example `OPENCTI_ADMIN_TOKEN` is consumed by OpenCTI workers/connectors and by OpenAEV integration env vars.

## Critical behavior to preserve
- `.env` is first-run only: `roles/xtm_deploy/tasks/main.yml` uses `stat` (`env_file`) and only generates/writes secrets when the file is absent.
- Secret generation runs on the controller (Python 3 lookups), not the target: `_uuid_cmd`, `_b64key_cmd`, and `lookup('password', '/dev/null', ...)`.
- `docker-compose.yml` is an upstream artifact; do not hand-edit in place (replace from upstream source).
- Docker role is intentionally dependency-light (`ansible.builtin.*` only; no `community.docker`).

## Conventions used in this codebase
- Use FQCN modules (`ansible.builtin.copy`, `ansible.builtin.command`, etc.).
- User-facing vars use domain prefixes (`opencti_*`, `openaev_*`, `smtp_*`, `imap_*`); generated/internal vars use leading `_` (for example `_uuids`, `_passwords`).
- Tasks that should not report changes set `changed_when: false` (example: Docker presence check).
- Keep secret values out of logs/output; avoid changes that expose generated credentials.

## Developer workflows
- Deploy: `ansible-playbook -i inventory/hosts.yml site.yml`.
- First setup: copy `inventory/hosts.yml.example` to `inventory/hosts.yml`, then set host/user/key.
- Syntax/lint from `README.md`: `ansible-playbook --syntax-check -i inventory/hosts.yml site.yml` and `ansible-lint`.
- Local VM test path is documented in `README.md` (Multipass) when a cloud target is unavailable.

## Platform note (Apple Silicon / ARM64)
- The Multipass VM on Apple M-series Macs runs natively as `linux/arm64`. Most stack images have native ARM64 support; only `opencti/connector-import-external-reference` is amd64-only — it has `platform: linux/amd64` pinned in `docker-compose.yml` so Docker runs it under x86_64 emulation.
- The docker role installs `qemu-user-static` + `binfmt-support` and registers the `qemu-x86_64` binfmt handler on ARM64 targets, enabling that one amd64 container to run.
- Do NOT add a global `DOCKER_DEFAULT_PLATFORM=linux/amd64` override — running JVM-based images (Elasticsearch, OpenCTI, OpenAEV) under x86_64 QEMU emulation causes `SIGSEGV` crashes. Use native ARM64 for everything except the one explicitly pinned service.

## Integration points and gotchas
- Port/base-url coupling matters: OpenCTI uses `${OPENCTI_PORT}` mapping; OpenAEV compose comment notes base URL must match host port changes.
- RabbitMQ runs with image defaults (no custom `rabbitmq.conf` bind mount).
- `xtm-composer` needs Docker socket and RSA key volume from `rsa-key-generator`; keep `depends_on` health conditions intact.
- Compose commands in the role are shell-outs (`docker compose pull`, `docker compose up -d --remove-orphans`) with custom `changed_when` parsing.
- **PostgreSQL 18+** changed the data directory from `/var/lib/postgresql/data` to a major-version subdirectory (`/var/lib/postgresql/18/data`). The volume in `docker-compose.yml` must be mounted at `/var/lib/postgresql` (not `.../data`) — a breaking change vs postgres 17.

## Safe change boundaries for agents
- Safe to edit: `group_vars/all.yml`, role tasks, `roles/xtm_deploy/templates/env.j2`, docs.
- Treat as upstream-managed: `roles/xtm_deploy/files/docker-compose.yml`.
- If adding new env vars, wire through all three layers: `group_vars/all.yml` -> `roles/xtm_deploy/templates/env.j2` -> compose service env usage.

