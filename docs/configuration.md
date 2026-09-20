# Configuration Reference

All configuration is done via `.env`. Copy `.env.example` to `.env` and edit.

```bash
cp .env.example .env
nano .env
```

> ⚠️ `.env` is gitignored. Never commit it.

---

## Core Services

### Grafana

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAFANA_PORT` | `3000` | Grafana web port |
| `GRAFANA_ADMIN_USER` | `admin` | Admin username |
| `GRAFANA_ADMIN_PASSWORD` | — | **Required.** Admin password |
| `GRAFANA_ROOT_URL` | `http://localhost:3000` | Public URL for Grafana |

### Prometheus

| Variable | Default | Description |
|----------|---------|-------------|
| `PROMETHEUS_PORT` | `9090` | Internal port (not exposed to host) |
| `PROM_USER` | `admin` | Basic auth username (via Caddy) |
| `PROM_BCRYPT_HASH` | — | **Required.** Bcrypt hash of password |

Generate bcrypt hash:
```bash
docker run --rm httpd:alpine htpasswd -nbB "$PROM_USER" 'your-password'
# Copy the hash after "user:" into PROM_BCRYPT_HASH
```

### Alertmanager

| Variable | Default | Description |
|----------|---------|-------------|
| `ALERTMANAGER_PORT` | `9093` | Internal port (not exposed to host) |
| `TELEGRAM_BOT_TOKEN` | — | **Required.** From [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_CHAT_ID` | — | **Required.** From [@userinfobot](https://t.me/userinfobot) |

### Loki

| Variable | Default | Description |
|----------|---------|-------------|
| `LOKI_PORT` | `3100` | Internal port (not exposed to host) |

### Uptime Kuma

| Variable | Default | Description |
|----------|---------|-------------|
| `UPTIME_KUMA_PORT` | `3001` | Uptime Kuma web port |

---

## Proxmox API

| Variable | Default | Description |
|----------|---------|-------------|
| `PVE_HOST` | `localhost` | Proxmox API host |
| `PVE_USER` | `root@pam` | **Recommended:** `monitoring@pve` |
| `PVE_PASSWORD` | — | **Required.** API password |
| `PVE_VERIFY_SSL` | `false` | Set `true` if using valid certs |

**Create a dedicated monitoring user on Proxmox:**

```bash
# On the Proxmox host:
pveum user add monitoring@pve --password <PASSWORD>
pveum role add Monitoring -privs "Sys.Audit VM.Audit Datastore.Audit"
pveum aclmod / -user monitoring@pve -role Monitoring
```

---

## Caddy (Reverse Proxy)

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAFANA_DOMAIN` | `grafana.local` | Domain for Grafana via Caddy |
| `KUMA_DOMAIN` | `status.local` | Domain for Uptime Kuma via Caddy |
| `PROMETHEUS_DOMAIN` | `prometheus.local` | Domain for Prometheus via Caddy |
| `ALERTS_DOMAIN` | `alerts.local` | Domain for Alertmanager via Caddy |

Add these to `/etc/hosts` (or your DNS) pointing to your monitoring server IP.

---

## Monitoring Targets

Target IPs are configured in `prometheus/targets/*.yml` (not `.env`).

| File | Purpose |
|------|---------|
| `prometheus/targets/pve-exporters.yml` | Proxmox node IPs |
| `prometheus/targets/node-exporters.yml` | All remote node_exporter IPs |
| `prometheus/targets/cadvisor-remote.yml` | Remote cAdvisor IPs |

These are read by the Uptime Kuma setup script:

| Variable | Description |
|----------|-------------|
| `PVE_NODE1_IP` | First Proxmox node IP |
| `PVE_NODE2_IP` | Second Proxmox node IP |
| `DOKPLOY_IP` | Docker host IP |

---

## Secrets

| Variable | Where used |
|----------|-----------|
| `TELEGRAM_BOT_TOKEN` | Alertmanager (rendered from template) |
| `TELEGRAM_CHAT_ID` | Alertmanager (rendered from template) |
| `GRAFANA_ADMIN_PASSWORD` | Grafana |
| `PVE_PASSWORD` | pve-exporter |
| `PROM_BCRYPT_HASH` | Caddy basic auth |

All secrets are injected into configs via `scripts/render-configs.sh` (envsubst). Rendered files (e.g. `alertmanager/alertmanager.yml`) are gitignored.

---

## Retention

| Backend | Retention | Config |
|---------|-----------|--------|
| Prometheus | 30 days | `prometheus/prometheus.yml` |
| Loki | 30 days | `loki/loki-config.yml` |
| Tempo | 7 days | `tempo/tempo.yml` |

---

## Backup

```bash
# Manual backup
./scripts/backup.sh /backup

# Cron (daily at 02:00)
0 2 * * * /opt/sentinel-stack/scripts/backup.sh /backup >> /var/log/sentinel-backup.log 2>&1
```

Backups include: configs + Prometheus, Loki, Grafana, Uptime Kuma volumes. Retention: 7 days.
