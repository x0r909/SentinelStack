# Deployment Guide

Step-by-step guide to deploy SentinelStack on your infrastructure.

---

## Prerequisites

| Requirement | Minimum |
|-------------|---------|
| CPU | 4 cores |
| RAM | 8 GB |
| Disk | 50–100 GB |
| OS | Ubuntu 22.04/24.04, Debian 11/12, or any Linux with Docker |
| Docker | v24+ with Compose plugin |
| Proxmox | API access (dedicated user recommended) |
| Telegram | Bot token + Chat ID |

---

## Step 1 — Server Setup

```bash
# Install Docker (if not present)
curl -fsSL https://get.docker.com | sh

# Clone the repository
git clone https://github.com/YOUR_USERNAME/sentinel-stack.git /opt/sentinel-stack
cd /opt/sentinel-stack
```

---

## Step 2 — Configure Environment

```bash
cp .env.example .env
nano .env
```

Fill in the required values:

| Variable | Description |
|----------|-------------|
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password |
| `TELEGRAM_BOT_TOKEN` | From [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_CHAT_ID` | From [@userinfobot](https://t.me/userinfobot) |
| `PVE_USER` | Proxmox API user (e.g. `monitoring@pve`) |
| `PVE_PASSWORD` | Proxmox API password |
| `PROM_USER` | Basic auth username for Prometheus/Alertmanager |
| `PROM_BCRYPT_HASH` | Bcrypt hash of password (see below) |

Generate the bcrypt hash:

```bash
docker run --rm httpd:alpine htpasswd -nbB "$PROM_USER" 'your-password'
# Copy the hash part (after "user:") into PROM_BCRYPT_HASH
```

---

## Step 3 — Configure Monitoring Targets

Edit the files in `prometheus/targets/` with your actual node IPs:

```yaml
# prometheus/targets/node-exporters.yml
- targets: ['192.168.1.10:9100']
  labels:
    host_type: 'proxmox'
    node_name: 'pve-1'
```

| File | Purpose |
|------|---------|
| `pve-exporters.yml` | Proxmox node IPs |
| `node-exporters.yml` | All remote node_exporter targets |
| `cadvisor-remote.yml` | Remote cAdvisor targets |

> Prometheus reloads automatically ~5 seconds after saving — no restart needed.

---

## Step 4 — Deploy Main Stack

```bash
cd /opt/sentinel-stack

# Render configs from templates (injects secrets from .env)
./scripts/render-configs.sh

# Deploy interactively
./deploy.sh
# Select option 1: Deploy Main Stack
```

Or manually:

```bash
docker compose pull
docker compose up -d
```

**Verify:**

```bash
docker compose ps
# All services should show "Up" or "Up (healthy)"
```

---

## Step 5 — Deploy Agents

### Proxmox Hosts (systemd native)

On each Proxmox host:

```bash
# Transfer and run the installer
scp agents/proxmox-node/install.sh root@<PROXMOX_IP>:/tmp/
ssh root@<PROXMOX_IP>

chmod +x /tmp/install.sh
MONITORING_SERVER=<MONITORING_SERVER_IP> NODE_HOSTNAME=pve-1 /tmp/install.sh
```

The installer:
- Installs `node_exporter` (port 9100) as a systemd service
- Installs Grafana Alloy as a systemd service (ships logs to Loki)
- Verifies both services are running

### Docker Hosts (e.g. Dokploy)

On the Docker host:

```bash
mkdir -p /opt/sentinel-agent
cd /opt/sentinel-agent

# Transfer files from monitoring server
# (run from monitoring server)
scp -r agents/dokploy-node/* root@<DOCKER_HOST_IP>:/opt/sentinel-agent/

# Back on the Docker host:
cp .env.example .env
nano .env
# Set:
#   LOKI_URL=http://<MONITORING_SERVER_IP>:3100/loki/api/v1/push
#   NODE_HOSTNAME=dokploy

docker compose up -d
```

---

## Step 6 — Verify All Targets

From the monitoring server:

```bash
docker compose exec prometheus wget -qO- \
  'http://localhost:9090/api/v1/targets?state=active' \
  | python3 -m json.tool | grep -E '"scrapeUrl"|"health"'
```

All targets should show `"health": "up"`.

---

## Step 7 — Test Telegram Alerting

```bash
./deploy.sh
# Select option 3: Test Telegram Alert
```

Or manually:

```bash
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "status": "firing",
    "labels": {"alertname": "TestAlert", "severity": "critical"},
    "annotations": {"summary": "Test alert from SentinelStack"}
  }]'
```

---

## Step 8 — Setup Uptime Kuma

1. Open `http://<MONITORING_IP>:3001`
2. Create admin account (first login)
3. Add monitors manually or use the setup script:

```bash
./scripts/setup-uptime-kuma-monitors.sh <KUMA_API_KEY>
```

See [uptime-kuma.md](uptime-kuma.md) for detailed setup.

---

## Step 9 — Setup Watchdog (Dead Man's Switch)

Protect against your monitoring stack going down silently:

1. Create a free check at [healthchecks.io](https://healthchecks.io)
2. Copy the ping URL (e.g. `https://hc-ping.com/<uuid>`)
3. Add to `alertmanager/alertmanager.yml.tmpl`:

```yaml
route:
  routes:
    - matchers:
        - alertname = "Watchdog"
      receiver: "deadman"
receivers:
  - name: "deadman"
    webhook_configs:
      - url: "https://hc-ping.com/<uuid>"
```

4. Re-render: `./scripts/render-configs.sh`

---

## Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | `http://<MONITORING_IP>:3000` | admin / (from `.env`) |
| Uptime Kuma | `http://<MONITORING_IP>:3001` | (set on first login) |
| Prometheus | `https://<PROMETHEUS_DOMAIN>` | basic auth (`PROM_USER`) |
| Alertmanager | `https://<ALERTS_DOMAIN>` | basic auth (`PROM_USER`) |
| Status Page | `http://<MONITORING_IP>:3001/status/<slug>` | Public |

---

## Maintenance

```bash
# Status
docker compose ps

# Logs
docker compose logs -f

# Restart a service
docker compose restart grafana

# Reload Prometheus config (no restart)
docker compose exec prometheus kill -HUP 1

# Update all services
docker compose pull && docker compose up -d

# Backup (configs + volumes)
./scripts/backup.sh /backup
```

---

## Troubleshooting

### Prometheus target DOWN

```bash
# Check firewall on the remote node
ufw allow from <MONITORING_IP> to any port 9100

# Test from monitoring server
curl http://<REMOTE_IP>:9100/metrics
```

### PVE Exporter error

```bash
# Test Proxmox API access
curl -k https://<PROXMOX_IP>:8006/api2/json/version \
  -u 'monitoring@pve:YOUR_PASSWORD'
```

### No Telegram alerts

```bash
# Re-render configs (if .env was updated)
./scripts/render-configs.sh

# Check alertmanager logs
docker compose logs alertmanager --tail 50
```

### Alloy not shipping logs

```bash
docker compose logs alloy --tail 50
# Check LOKI_URL is correct in .env
```
