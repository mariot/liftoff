# Copilot Instructions — Liftoff

## Project overview
**Liftoff** is an Ansible project that deploys the **XTM stack** (OpenCTI + OpenAEV) via Docker Compose on a fresh Linux server.

## Project structure
```
liftoff/
├── site.yml                          # Main playbook — runs docker + xtm_deploy roles
├── inventory/hosts.yml               # Target server inventory (gitignored)
├── inventory/hosts.yml.example       # Inventory template
├── group_vars/all.yml                # User-configurable variables
└── roles/
    ├── docker/                       # Installs Docker Engine + Compose plugin
    │   ├── tasks/main.yml            # Supports Debian/Ubuntu and RHEL/Rocky/Alma
    │   └── handlers/main.yml
    └── xtm_deploy/                   # Deploys the XTM stack
        ├── tasks/main.yml            # Copies files, generates secrets, runs compose
        ├── files/docker-compose.yml  # Stack definition (do NOT edit — sourced from xtm-docker)
        ├── files/rabbitmq.conf       # RabbitMQ config (do NOT edit — sourced from xtm-docker)
        └── templates/env.j2          # .env template (all secrets injected at render time)
```

## Key design decisions

### Secret generation
- All secrets (UUIDs, passwords, encryption keys) are generated **on the Ansible controller** using Python 3 — no `uuidgen`, `openssl`, or other tools required on the target server.
- `lookup('pipe', 'python3 -c "import uuid; print(uuid.uuid4())"')` for UUIDs
- `lookup('password', '/dev/null', length=32, chars=[...])` for passwords (built-in Ansible)
- `lookup('pipe', 'python3 -c "import secrets,base64; ..."')` for base64 encryption keys
- The `.env` file is written **once** and never overwritten (idempotent — guarded by a `stat` check).

### Files not to modify
- `roles/xtm_deploy/files/docker-compose.yml` and `roles/xtm_deploy/files/rabbitmq.conf` are copied verbatim from the upstream `xtm-docker` repo. Update them by re-copying from source, never editing in place.

### Variable naming
- All user-facing variables live in `group_vars/all.yml` with the prefix matching their domain (`opencti_*`, `openaev_*`, `smtp_*`, `imap_*`).
- Internal/generated variables use a `_` prefix (`_uuids`, `_passwords`, `_opencti_encryption_key`).

### Supported OS families
- `Debian` (Ubuntu, Debian) — uses `apt` + Docker's official APT repo
- `RedHat` (CentOS, Rocky, AlmaLinux) — uses `dnf` + Docker's official DNF repo

## Conventions
- Use FQCNs for all Ansible modules (e.g. `ansible.builtin.copy`, not just `copy`).
- Tasks that make no changes on the remote should set `changed_when: false`.
- Secrets must never be logged; avoid `no_log: false` overrides on secret-related tasks.
- Keep the `docker` role dependency-free (no `community.docker` collection required).
- The project requires **Ansible ≥ 2.14** and **Python 3** on the controller.

## Running the playbook
```bash
ansible-playbook -i inventory/hosts.yml site.yml
```
Re-runs are safe: Docker installation is skipped if present, `.env` is never regenerated.
