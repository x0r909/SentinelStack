<div align="center">

```
███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗
██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║
███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║
╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║
███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗
╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
███████╗████████╗ █████╗  ██████╗██╗  ██╗
██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝
███████╗   ██║   ███████║██║     █████╔╝
╚════██║   ██║   ██╔══██║██║     ██╔═██╗
███████║   ██║   ██║  ██║╚██████╗██║  ██╗
╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
```

**All-in-one monitoring & uptime platform for Proxmox, Docker, and Linux servers.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)](https://docs.docker.com/compose/)
[![Grafana](https://img.shields.io/badge/Grafana-11.x-orange?logo=grafana)](https://grafana.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-2.54-red?logo=prometheus)](https://prometheus.io/)

</div>

---

## ✨ Features

- 📊 **Proxmox Monitoring** — Cluster health, VM/LXC status, storage, CPU/RAM per node
- 🐳 **Docker Metrics** — Auto-discover all containers, resource usage, restart tracking
- 🖥️ **System Metrics** — CPU, RAM, disk, network for all nodes
- 📋 **Centralized Logs** — Grafana Alloy → Loki (30-day retention)
- 🔍 **Distributed Tracing** — Tempo + OTLP receiver (7-day retention)
- 🚨 **Alerting** — 30+ alert rules → Telegram, including Watchdog dead man's switch
- 📈 **Uptime Monitoring** — Status page for all services via Uptime Kuma
- 🔒 **Reverse Proxy** — Caddy with auto TLS + basic auth for Prometheus/Alertmanager
- 🔐 **Secret Management** — Credentials in `.env`, rendered via templates (never committed)
- ⚡ **File-based SD** — Add nodes by editing `prometheus/targets/*.yml` (no restart)
- 📦 **Pre-built Dashboards** — Grafana dashboards ready to use

---

## 🏗️ Architecture

```
                    ┌──────────────────────────────────────────────┐
                    │            Caddy (reverse proxy)             │
                    │   TLS internal + basic auth (prom/alerts)    │
                    └───────┬──────────┬──────────┬───────────────┘
                            │          │          │
┌───────────────────────────┴──────────┴──────────┴───────────────────────────┐
│                      sentinel-frontend network                              │
│  ┌───────────┐ ┌──────────┐ ┌─────────┐ ┌──────────────┐ ┌──────────────┐   │
│  │  Grafana  │ │Prometheus│ │  Loki   │ │ Alertmanager │ │ Uptime Kuma  │   │
│  │   :3000   │ │  :9090   │ │  :3100  │ │    :9093     │ │    :3001     │   │
│  └───────────┘ └──────────┘ └─────────┘ └──────────────┘ └──────────────┘   │
├──────────────────────────────────────────────────────────────────────────────┤
│                      sentinel-backend network                               │
│  ┌───────┐ ┌────────┐ ┌──────────────┐ ┌─────────────────────────────────┐  │
│  │ Tempo │ │  Alloy │ │ pve-exporter │ │ blackbox / cadvisor / node-exp  │  │
│  │ :3200 │ │ :12345 │ │    :9221     │ │       (sentinel-exporters)      │  │
│  └───────┘ └────────┘ └──────────────┘ └─────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
    ┌────┴────┐         ┌────┴────┐         ┌────┴────┐
    │Proxmox 1│         │Proxmox 2│         │ Docker  │
    │(systemd │         │(systemd │         │  Host   │
    │ agent)  │         │ agent)  │         │(Alloy   │
    └─────────┘         └─────────┘         │container)│
                                            └─────────┘
```

**Network segmentation:**

| Network | Purpose |
|---------|---------|
| `sentinel-frontend` | Services accessible via Caddy |
| `sentinel-backend` | Internal service communication |
| `sentinel-exporters` | `internal: true` — no internet access |

---

## 🚀 Quick Start

### 1. Clone & Configure

```bash
git clone https://github.com/YOUR_USERNAME/sentinel-stack.git /opt/sentinel-stack
cd /opt/sentinel-stack

cp .env.example .env
nano .env
```

Fill in the required values — see [Configuration Reference](docs/configuration.md).

### 2. Add Your Nodes

Edit `prometheus/targets/*.yml` with your node IPs:

```yaml
# prometheus/targets/node-exporters.yml
- targets: ['192.168.1.10:9100']
  labels:
    host_type: 'proxmox'
    node_name: 'pve-1'
```

### 3. Deploy

```bash
./scripts/render-configs.sh   # inject secrets into config templates
./deploy.sh                   # interactive deployment
```

Or one-shot:

```bash
./setup.sh
```

### 4. Access

| Service | URL |
|---------|-----|
| Grafana | `http://<SERVER_IP>:3000` |
| Uptime Kuma | `http://<SERVER_IP>:3001` |
| Prometheus | `https://<PROMETHEUS_DOMAIN>` |
| Alertmanager | `https://<ALERTS_DOMAIN>` |

---

## 📖 Documentation

| Guide | Description |
|-------|-------------|
| [Deployment Guide](docs/deployment.md) | Full step-by-step deployment |
| [Agent Setup](docs/agents.md) | Install agents on Proxmox / Docker hosts |
| [Configuration Reference](docs/configuration.md) | All `.env` variables explained |
| [Uptime Kuma Setup](docs/uptime-kuma.md) | Uptime monitoring + status page |

---

## 🔔 Alert Rules

All rules live in `prometheus/rules/` — modular by category:

| File | Category | Highlights |
|------|----------|-----------|
| `node.yml` | Node | CPU/memory/disk/load warnings + critical |
| `proxmox.yml` | Proxmox | Node offline, VM/LXC down, storage critical |
| `docker.yml` | Docker | Container CPU/memory/restart loop |
| `service.yml` | Service | Service down, config reload failed, **Watchdog** |
| `storage.yml` | Storage + v2.0 | TSDB limits, **SSL cert expiry**, **OOM kill**, **host reboot**, **network saturation**, **probe failure**, **Tempo errors** |

### Watchdog (Dead Man's Switch)

The `Watchdog` alert always fires. Route it to [healthchecks.io](https://healthchecks.io) — if the ping stops, healthchecks.io notifies you. This protects against the monitoring stack itself going down silently.

See [deployment.md](docs/deployment.md#step-9--setup-watchdog-dead-mans-switch) for setup.

---

## 🛠️ Maintenance

```bash
# Check status
docker compose ps

# Reload Prometheus config (no restart)
docker compose exec prometheus kill -HUP 1

# Backup (configs + volumes, 7-day retention)
./scripts/backup.sh /backup

# Update stack
docker compose pull && docker compose up -d
```

---

## 📁 Project Structure

```
sentinel-stack/
├── docker-compose.yml          # Main stack (12 services, 3 networks)
├── .env.example                # Environment template
├── setup.sh                    # One-shot setup
├── deploy.sh                   # Interactive deployment helper
├── caddy/
│   └── Caddyfile               # Reverse proxy, TLS, basic auth
├── prometheus/
│   ├── prometheus.yml          # Scrape config (file_sd)
│   ├── targets/                # ← Add nodes here
│   │   ├── pve-exporters.yml
│   │   ├── node-exporters.yml
│   │   └── cadvisor-remote.yml
│   └── rules/                  # Alert rules (modular)
├── alertmanager/
│   ├── alertmanager.yml.tmpl   # Template (secrets via ${VAR})
│   └── alertmanager.yml        # Rendered (gitignored)
├── loki/loki-config.yml        # Log storage (30d)
├── alloy/config.alloy          # Log collector
├── tempo/tempo.yml             # Tracing backend (7d)
├── grafana/
│   ├── provisioning/datasources/
│   └── dashboards/
├── scripts/
│   ├── render-configs.sh       # Render templates with secrets
│   ├── backup.sh               # Config + volume backup
│   └── setup-uptime-kuma-monitors.sh
├── agents/
│   ├── proxmox-node/           # systemd installer
│   └── dokploy-node/           # Docker Compose agent
└── docs/
    ├── deployment.md
    ├── agents.md
    ├── configuration.md
    └── uptime-kuma.md
```

---

## 🖥️ Resource Requirements

### Monitoring Server

| Resource | Minimum |
|----------|---------|
| CPU | 4 cores |
| RAM | 8 GB |
| Disk | 50–100 GB |
| OS | Ubuntu 22.04/24.04, Debian 11/12 |

### Per Agent Node

| Resource | Minimum |
|----------|---------|
| CPU | 0.5 core |
| RAM | 512 MB |
| Ports | 9100 (node_exporter), 8080 (cAdvisor) |

---

## 🔐 Security Model

1. **Secrets never in git** — all credentials in `.env` (gitignored), rendered via `scripts/render-configs.sh`
2. **No exposed internal ports** — only Caddy, Grafana, Uptime Kuma listen on the host
3. **Basic auth** for Prometheus & Alertmanager via Caddy
4. **TLS internal** auto-generated for all domains via Caddy
5. **Network segmentation** — exporters isolated (`internal: true`)
6. **Dedicated PVE user** — `monitoring@pve` with `PVEAuditor` role (not root)
7. **Watchdog** — detects if the monitoring stack itself goes down

---

## 📦 Stack Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Grafana | 11.2 | Visualization & dashboards |
| Prometheus | 2.54 | Metrics collection (30d) |
| Alertmanager | 0.27 | Alert routing & deduplication |
| Loki | 3.1 | Log aggregation (30d) |
| Grafana Alloy | 0.2 | Telemetry collector |
| Tempo | 2.6 | Distributed tracing (7d) |
| Caddy | 2.8 | Reverse proxy + TLS |
| Uptime Kuma | 1.23 | Uptime monitoring & status pages |

---

## 🤝 Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
