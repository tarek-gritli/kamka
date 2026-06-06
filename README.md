# Kamka Assessment — React + Express + MariaDB

A three-tier web application (React frontend, Node/Express API, MariaDB database) used as a vehicle for demonstrating containerization, CI/CD, monitoring, and operational automation.

---

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Caddy (port 80/443)      │
                    │         Reverse Proxy / TLS       │
                    └────────────┬────────────┬─────────┘
                                 │            │
                    ┌────────────▼──┐    ┌────▼────────────┐
                    │   Frontend    │    │    Backend API   │
                    │  nginx:alpine │    │   node:alpine    │
                    │   port 8080   │    │    port 80       │
                    └───────────────┘    └────────┬─────────┘
                                                  │
                                         ┌────────▼─────────┐
                                         │     MariaDB       │
                                         │  (private network)│
                                         └───────────────────┘

                    ┌───────────────────┐
                    │   Uptime Kuma     │  monitors all services
                    │   port 3001       │
                    └───────────────────┘
```

**Networks:**
- `public` — frontend, backend, Caddy, Uptime Kuma
- `private` — backend, Uptime Kuma, and MariaDB (DB is never exposed to the public network)

---

## Prerequisites

- Docker >= 24 and Docker Compose v2 (`docker compose`)
- Git

---

## Local Development

### 1. Clone and configure

```bash
git clone https://github.com/tarek-gritli/kamka-assessment.git
cd kamka-assessment
cp .env.example .env
# Edit .env and set your own passwords
```

### 2. Start the dev stack

```bash
docker compose up -d
```

This brings up:
- Frontend (React dev server with hot reload) → http://localhost:3000
- Backend (Node with nodemon) → http://localhost:80
- MariaDB → internal only

### 3. Verify it's running

```bash
docker compose ps
curl http://localhost/healthz     # backend health
curl http://localhost:3000        # frontend
```

### 4. Stop

```bash
docker compose down
# To also remove volumes (wipes DB):
docker compose down -v
```

---

## Production Deployment

### First-time host setup

On a fresh Ubuntu/Debian server:

```bash
sudo ./scripts/bootstrap.sh
# Log out and back in for docker group to take effect
```

This installs Docker, creates `/opt/kamka`, and opens ports 80, 443, 3001.

### Deploy

```bash
cd /opt/kamka
git clone https://github.com/tarek-gritli/kamka-assessment.git .
cp .env.example .env
nano .env   # fill in real values — see "Secrets" section below

docker compose -f compose.prod.yml up -d
```

Or using the deploy script (used by CI):

```bash
./scripts/deploy.sh <image-tag>
# Example: ./scripts/deploy.sh sha-a1b2c3d
```

### Rollback

```bash
./scripts/rollback.sh           # reverts to previous release
./scripts/rollback.sh sha-abc   # reverts to a specific tag
```

### Dev vs prod differences

| Concern | Dev (`compose.yaml`) | Prod (`compose.prod.yml`) |
|---|---|---|
| Build target | `development` (devDeps, hot reload) | `production` (alpine, non-root, no devDeps) |
| Frontend | React dev server on port 3000 | nginx on port 8080 serving static build |
| Reverse proxy | None (ports exposed directly) | Caddy on port 80, auto TLS on port 443 |
| Secrets | `.env` file | CI secret store → env vars |
| DB password | `.env` variable | `.env` variable (never in compose file) |

---

## Secrets

**No secrets are committed to this repository.**

| What | How |
|---|---|
| Local dev | Copy `.env.example` → `.env`, fill in values. `.env` is gitignored. |
| CI/CD | Set `DATABASE_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY` as GitHub Actions secrets under Settings → Secrets. |
| Production host | `.env` file on the server, owned by the deploy user, mode `600`. |

Required variables (see `.env.example` for full list):

```
DATABASE_DB=example
DATABASE_USER=root
DATABASE_PASSWORD=<strong-password>
MYSQL_ROOT_PASSWORD=<same-strong-password>
```

---

## CI/CD Pipeline

GitHub Actions (`.github/workflows/ci.yml`) runs on every push:

```
push → lint-and-test → build-and-push → deploy (main only)
```

| Stage | What happens |
|---|---|
| `lint-and-test` | Installs deps, runs backend and frontend tests |
| `build-and-push` | Builds production Docker images, pushes to GHCR with `sha-<commit>` and `latest` tags |
| `deploy` | SSH into production host, runs `./scripts/deploy.sh <tag>` (main branch only) |

Images are published to GitHub Container Registry (`ghcr.io/<owner>/kamka-backend` and `kamka-frontend`).

**Required GitHub secrets for deploy:**

| Secret | Value |
|---|---|
| `DEPLOY_HOST` | IP or hostname of production server |
| `DEPLOY_USER` | SSH user on that server |
| `DEPLOY_SSH_KEY` | Private SSH key (add the public key to `~/.ssh/authorized_keys` on server) |

Also set **Settings → Actions → General → Workflow permissions** to **Read and write** so the pipeline can push to GHCR.

---

## Monitoring

Uptime Kuma runs as part of the production stack and is accessible at `http://<host>:3001`.

On first visit, create an admin account, then add monitors:

| Monitor | Type | URL / Host | Port |
|---|---|---|---|
| Frontend | HTTP(s) | `http://frontend:8080/health` | — |
| Backend | HTTP(s) | `http://backend:80/healthz` | — |
| Database | TCP Port | `db` | `3306` |

Uptime Kuma is on both the `public` and `private` networks so it can reach all services by container name directly.

---

## Scripts

| Script | Purpose |
|---|---|
| `scripts/bootstrap.sh` | Provision a fresh Ubuntu/Debian host (Docker, firewall, app dir) |
| `scripts/deploy.sh <tag>` | Pull and start a specific image tag, verify health, record release |
| `scripts/rollback.sh [tag]` | Revert to previous (or specified) release |

All scripts use `set -euo pipefail` — they fail loudly on any error, unset variable, or failed pipe.

---

## Known Limitations

- **No staging environment** — dev and prod are the only environments. With more time, a staging compose profile using the same production images but a separate database would be the next step.
- **Single-host deployment** — no orchestration (Kubernetes, Swarm). Acceptable for this scope; would not scale horizontally as-is.
- **Uptime Kuma is self-monitored** — if the host goes down, so does the monitoring. A hosted uptime service (Better Uptime, etc.) would be the production answer.
- **MariaDB backup** — no automated backup script included. In production, a cron job running `mysqldump` to object storage would be required.
- **Caddy TLS** — the current Caddyfile listens on `:80` (plain HTTP). To enable HTTPS in production, replace `:80` in the Caddyfile with your domain name — Caddy will auto-provision a Let's Encrypt certificate.
