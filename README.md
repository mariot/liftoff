# Liftoff 🚀

Ansible project that deploys the **XTM stack** — [OpenCTI](https://github.com/OpenCTI-Platform/opencti) (cyber threat intelligence platform) and [OpenAEV](https://github.com/OpenAEV-Platform/openaev) (attack emulation & validation platform) — on a fresh Linux server using Docker Compose.

## What it does

1. **Installs Docker** (Engine + Compose plugin) if not already present — supports Debian/Ubuntu and RHEL/CentOS/Rocky/AlmaLinux.
2. **Generates all secrets once**: every UUID (connector IDs, admin tokens), password, and encryption key is created on the Ansible controller using Python 3 — no extra tools needed on the target server. The resulting `.env` file is written once and **never overwritten** on subsequent runs.
3. **Brings up the full stack** with `docker compose up -d`, including OpenCTI, OpenAEV, workers, connectors, collectors, injectors, and all dependencies (Elasticsearch, Redis, RabbitMQ, MinIO, PostgreSQL).

## Requirements

**Controller (your machine):**
- Ansible ≥ 2.14
- Python 3

**Target server:**
- Debian/Ubuntu or RHEL/CentOS/Rocky/AlmaLinux
- SSH access with a user that has `sudo` privileges
- Minimum 16 GB RAM, 4 CPUs, 50 GB disk (Elasticsearch alone needs 4 GB heap)

## Quick start

```bash
# 1. Clone this repo
git clone <repo-url> liftoff && cd liftoff

# 2. Copy and edit the inventory
cp inventory/hosts.yml.example inventory/hosts.yml
vi inventory/hosts.yml   # set your server IP and SSH user

# 3. Optionally configure variables (admin emails, ports, SMTP, etc.)
vi group_vars/all.yml

# 4. Deploy
ansible-playbook -i inventory/hosts.yml site.yml
```

On first run the playbook generates all secrets and writes `/opt/xtm/.env` on the server. **Re-runs are safe** — Docker installation and secret generation are both skipped if already done.

## Project structure

```
liftoff/
├── site.yml                        # Main playbook
├── inventory/
│   ├── hosts.yml                   # Your inventory (gitignored)
│   └── hosts.yml.example           # Inventory template
├── group_vars/
│   └── all.yml                     # User-configurable variables
└── roles/
    ├── docker/                     # Installs Docker Engine + Compose plugin
    │   ├── tasks/main.yml
    │   └── handlers/main.yml
    └── xtm_deploy/                 # Deploys the XTM stack
        ├── tasks/main.yml
        ├── files/
        │   ├── docker-compose.yml  # Stack definition (sourced from xtm-docker — do not edit)
        │   └── rabbitmq.conf       # RabbitMQ config  (sourced from xtm-docker — do not edit)
        └── templates/
            └── env.j2              # .env template (secrets injected at deploy time)
```

## Configuration (`group_vars/all.yml`)

| Variable | Default | Description |
|---|---|---|
| `xtm_deploy_dir` | `/opt/xtm` | Deployment directory on the target server |
| `opencti_host` | server IP | Hostname or IP used in the OpenCTI public URL |
| `opencti_port` | `8080` | Public port for OpenCTI |
| `opencti_admin_email` | `admin@opencti.io` | OpenCTI admin account email |
| `openaev_host` | server IP | Hostname or IP used in the OpenAEV public URL |
| `openaev_port` | `8081` | Public port for OpenAEV |
| `openaev_admin_email` | `admin@openaev.io` | OpenAEV admin account email |
| `elastic_memory_size` | `4G` | Elasticsearch JVM heap (set to ~50% of RAM) |
| `minio_root_user` | `opencti` | MinIO root username |
| `rabbitmq_user` | `xtmrabbit` | RabbitMQ username |
| `postgres_user` | `xtmpgsql` | PostgreSQL username |
| `smtp_*` | — | Outgoing mail settings (optional) |
| `imap_*` / `openaev_mail_imap_enabled` | `false` | Incoming mail for OpenAEV (optional) |
| `collector_nvd_nist_cve_api_key` | `""` | NVD NIST API key (optional but recommended) |

All passwords, tokens, UUIDs, and encryption keys are **auto-generated** — do not set them here.

## Accessing the services

After a successful deploy, the stack is available at:

| Service | URL | Notes |
|---|---|---|
| OpenCTI | `http://<host>:8080` | Login with `opencti_admin_email` |
| OpenAEV | `http://<host>:8081` | Login with `openaev_admin_email` |
| RabbitMQ UI | `http://<host>:15672` | Message broker management |
| MinIO | `http://<host>:9000` | Object storage |
| Elasticsearch | `http://<host>:9200` | Search engine |

Generated credentials are stored in `/opt/xtm/.env` on the server.

---

## Testing locally with Multipass

[Multipass](https://multipass.run) spins up lightweight Ubuntu VMs on macOS (or Linux/Windows) — ideal for testing this playbook without a cloud server.

### 1. Install Multipass

```bash
brew install --cask multipass
```

### 2. Launch a VM

```bash
multipass launch --name xtm-test --cpus 4 --memory 10G --disk 50G
```

> Elasticsearch requires at least 4 GB JVM heap plus overhead. 10 GB total is a safe minimum for the full stack.

### 3. Set up SSH access

Multipass VMs use their own key. The easiest way to connect is via `multipass exec`, but Ansible needs a standard SSH key:

```bash
# Copy your public key into the VM
cat ~/.ssh/id_rsa.pub | multipass exec xtm-test -- bash -c "cat >> ~/.ssh/authorized_keys"

# Get the VM's IP
multipass info xtm-test | grep IPv4
```

### 4. Configure the inventory

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

Edit `inventory/hosts.yml`:

```yaml
all:
  children:
    xtm_servers:
      hosts:
        xtm-test:
          ansible_host: <multipass-ip>
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### 5. Run the playbook

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

The first run takes several minutes — Docker images are large. Subsequent runs are fast.

### 6. Access the services

Use the Multipass VM IP in your browser:

```
http://<multipass-ip>:8080   → OpenCTI
http://<multipass-ip>:8081   → OpenAEV
```

### 7. Tear down

```bash
multipass delete xtm-test && multipass purge
```

This removes the VM and all its data cleanly.

---

### Syntax check (no VM needed)

```bash
pip install ansible ansible-lint
ansible-playbook --syntax-check -i inventory/hosts.yml site.yml
ansible-lint
```
