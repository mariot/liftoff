# Liftoff 🚀

Ansible project to deploy the **XTM stack** (OpenCTI + OpenAEV) via Docker Compose on a fresh server.

## What it does

1. **Installs Docker** (Engine + Compose plugin) if not already present — supports Debian/Ubuntu and RHEL/CentOS/Rocky/Alma.
2. **Generates secrets once** on first deploy: all UUIDs (connectors, tokens, IDs) and all passwords/encryption keys are created on the remote host using `uuidgen` and `openssl rand`. The resulting `.env` file is **never overwritten** on subsequent runs (idempotent).
3. **Brings up the stack** with `docker compose up -d`.

## Requirements

- Ansible ≥ 2.14
- Target server running a supported Linux distribution
- SSH access with a user that has `sudo` privileges

## Quick start

```bash
# 1. Clone this repo
git clone <repo-url> liftoff && cd liftoff

# 2. Edit inventory
vi inventory/hosts.yml   # set your server IP and SSH user

# 3. (Optional) Override variables
vi group_vars/all.yml    # set admin emails, SMTP settings, ports, etc.

# 4. Run
ansible-playbook -i inventory/hosts.yml site.yml
```

## Project structure

```
liftoff/
├── site.yml                        # Main playbook
├── inventory/
│   └── hosts.yml                   # Target server(s)
├── group_vars/
│   └── all.yml                     # User-configurable variables
└── roles/
    ├── docker/                     # Installs Docker if missing
    │   ├── tasks/main.yml
    │   └── handlers/main.yml
    └── xtm_deploy/                 # Deploys the XTM stack
        ├── tasks/main.yml
        ├── files/
        │   ├── docker-compose.yml  # Stack definition (from xtm-docker)
        │   └── rabbitmq.conf       # RabbitMQ config (from xtm-docker)
        └── templates/
            └── env.j2              # .env template (secrets injected at runtime)
```

## Variables (`group_vars/all.yml`)

| Variable | Default | Description |
|---|---|---|
| `xtm_deploy_dir` | `/opt/xtm` | Directory on the remote server |
| `opencti_host` | server IP | Hostname/IP for the OpenCTI URL |
| `opencti_port` | `8080` | Public port for OpenCTI |
| `opencti_admin_email` | `admin@opencti.io` | OpenCTI admin account |
| `openaev_host` | server IP | Hostname/IP for the OpenAEV URL |
| `openaev_port` | `8081` | Public port for OpenAEV |
| `openaev_admin_email` | `admin@openaev.io` | OpenAEV admin account |
| `elastic_memory_size` | `4G` | JVM heap for Elasticsearch |
| `smtp_*` / `imap_*` | — | Mail settings (optional) |
| `collector_nvd_nist_cve_api_key` | `""` | NVD NIST API key (optional but recommended) |

## Re-running the playbook

Re-running the playbook is safe:
- Docker installation is skipped if Docker is already present.
- The `.env` file is **never regenerated** if it already exists.
- `docker compose up -d` is idempotent — only changed/new containers are updated.

## Accessing the services

| Service | URL |
|---|---|
| OpenCTI | `http://<host>:8080` |
| OpenAEV | `http://<host>:8081` |
| RabbitMQ management | `http://<host>:15672` |
| MinIO | `http://<host>:9000` |
| Elasticsearch | `http://<host>:9200` |

Credentials are stored in `{{ xtm_deploy_dir }}/.env` on the remote server.
