# 🛡️ SentinelStack

**All-in-One System Monitoring & Uptime Platform**

Unified monitoring solution untuk Proxmox cluster, Docker containers, dan infrastructure logs dengan alerting ke Telegram.

---

## 📋 Features

- ✅ **Full Proxmox Monitoring** — Cluster health, VM/LXC status, storage, CPU/RAM per node
- ✅ **Docker Container Metrics** — Auto-discover semua containers, resource usage, restart tracking
- ✅ **System Metrics** — CPU, RAM, disk, network untuk semua nodes
- ✅ **Centralized Logs** — Aggregasi logs dari Docker, Proxmox, dan system logs (30 hari retention)
- ✅ **Alerting** — 20+ alert rules ke Telegram (CPU high, disk full, service down, dll)
- ✅ **Uptime Monitoring** — Status page untuk semua services
- ✅ **Pre-built Dashboards** — 4 Grafana dashboards siap pakai

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SentinelStack (LXC/VM)                        │
│  ┌───────────┐ ┌──────────┐ ┌─────────┐ ┌───────────────────┐  │
│  │  Grafana   │ │Prometheus│ │  Loki   │ │  Uptime Kuma      │  │
│  │ :3000     │ │ :9090    │ │ :3100   │ │  :3001            │  │
│  └─────┬─────┘ └────┬─────┘ └────┬────┘ └────────┬──────────┘  │
│        │             │            │                │             │
│  ┌─────┴─────┐  ┌───┴────┐  ┌───┴────┐   ┌──────┴──────┐     │
│  │Alertmanager│ │cAdvisor│  │Promtail│   │Telegram Bot │     │
│  │  :9093     │ │ :8080  │  │        │   │             │     │
│  └────────────┘ └────────┘  └────────┘   └─────────────┘     │
└─────────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
    ┌────┴────┐         ┌────┴────┐         ┌────┴────┐
    │Proxmox 1│         │Proxmox 2│         │Dokploy  │
    │(agent)  │         │(agent)  │         │(agent)  │
    └─────────┘         └─────────┘         └─────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose v2+
- LXC/VM dengan 4 core CPU, 8GB RAM, 50-100GB disk
- Access ke Proxmox API
- Telegram bot token

### 1. Clone & Setup

```bash
git clone <repo-url> /opt/sentinel-stack
cd /opt/sentinel-stack

# Copy dan edit environment variables
cp .env.example .env
nano .env
```

**Environment yang WAJIB diisi:**
- `GRAFANA_ADMIN_PASSWORD` — Password Grafana
- `PVE_NODE1_IP` / `PVE_NODE2_IP` — IP Proxmox nodes
- `PVE_PASSWORD` — Password Proxmox API
- `DOKPLOY_IP` — IP server Dokploy
- `TELEGRAM_BOT_TOKEN` — Dari @BotFather
- `TELEGRAM_CHAT_ID` — Dari @userinfobot

### 2. Update Prometheus Targets

```bash
# Ganti placeholder dengan IP asli
sed -i 's/PROXMOX_NODE1_IP/192.168.1.10/g' prometheus/prometheus.yml
sed -i 's/PROXMOX_NODE2_IP/192.168.1.11/g' prometheus/prometheus.yml
sed -i 's/DOKPLOY_IP/192.168.1.20/g' prometheus/prometheus.yml
```

### 3. Update Alertmanager

```bash
# Ganti dengan Telegram credentials lo
sed -i "s/TELEGRAM_BOT_TOKEN/YOUR_BOT_TOKEN/g" alertmanager/alertmanager.yml
sed -i "s/TELEGRAM_CHAT_ID/YOUR_CHAT_ID/g" alertmanager/alertmanager.yml
```

### 4. Deploy Main Stack

```bash
# Otomatis setup
chmod +x setup.sh
./setup.sh

# Atau manual
docker compose up -d
```

### 5. Deploy Agents

**Di setiap Proxmox node:**
```bash
# Transfer files
scp -r agents/proxmox-node/* root@PROXMOX_IP:/opt/sentinel-agent/

# SSH ke node
ssh root@PROXMOX_IP
cd /opt/sentinel-agent

# Setup & start
cp .env.example .env
nano .env  # Edit LOKI_URL dan NODE_HOSTNAME
docker compose up -d
```

**Di Dokploy server:**
```bash
# Transfer files
scp -r agents/dokploy-node/* root@DOKPLOY_IP:/opt/sentinel-agent/

# SSH ke server
ssh root@DOKPLOY_IP
cd /opt/sentinel-agent

# Setup & start
cp .env.example .env
nano .env  # Edit LOKI_URL dan NODE_HOSTNAME
docker compose up -d
```

---

## 🎯 Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | `http://MONITORING_IP:3000` | admin / (dari .env) |
| **Prometheus** | `http://MONITORING_IP:9090` | - |
| **Alertmanager** | `http://MONITORING_IP:9093` | - |
| **Uptime Kuma** | `http://MONITORING_IP:3001` | (setup pertama kali) |
| **Loki** | `http://MONITORING_IP:3100` | - |

---

## 📊 Dashboards

Pre-built Grafana dashboards di folder **SentinelStack**:

1. **Proxmox Cluster Overview**
   - Cluster nodes count, VM/LXC status
   - CPU/Memory usage per node
   - Storage usage per pool

2. **Docker Container Overview**
   - Running/stopped containers
   - CPU/Memory per container
   - Network I/O
   - Restart count

3. **Node System Overview**
   - System metrics (CPU, RAM, disk, network)
   - Load average
   - Disk I/O

4. **Logs Explorer**
   - Unified log search
   - Error analysis
   - Container logs viewer

---

## 🔔 Alert Rules

### Node Alerts
- High CPU (>85%)
- Critical CPU (>95%)
- High Memory (>85%)
- Critical Memory (>95%)
- Disk Space Warning (>85%)
- Disk Space Critical (>95%)
- High Load Average

### Proxmox Alerts
- Node Offline
- VM/LXC Down
- High CPU/Memory
- Storage Critical (>90%)

### Docker Alerts
- Container Down
- Container High CPU (>80%)
- Container High Memory (>85%)
- Container Restart Loop (>5 restarts/hour)

### Service Alerts
- Service Down (>2 min)
- Multiple Targets Missing
- Prometheus Compaction Failed
- Alertmanager Config Failed

---

## 🛠️ Maintenance

### Check Status
```bash
cd /opt/sentinel-stack
docker compose ps
docker compose logs -f
```

### Restart Service
```bash
docker compose restart grafana
docker compose restart prometheus
```

### Update Stack
```bash
docker compose pull
docker compose up -d
```

### Stop Stack
```bash
docker compose down
```

### Backup Config
```bash
tar -czf sentinel-backup-$(date +%Y%m%d).tar.gz \
  .env prometheus/ alertmanager/ loki/ promtail/ grafana/
```

---

## 📝 Configuration Files

```
monitoring-system/
├── docker-compose.yml              # Main stack (9 services)
├── .env.example                    # Environment template
├── setup.sh                        # Interactive setup
├── prometheus/
│   ├── prometheus.yml              # Scrape config
│   └── alert-rules.yml             # Alert rules
├── alertmanager/
│   └── alertmanager.yml            # Telegram alerting
├── loki/
│   └── loki-config.yml             # Log storage (30d retention)
├── promtail/
│   └── promtail-config.yml         # Log collection
├── grafana/
│   ├── provisioning/               # Auto-provision config
│   └── dashboards/                 # Pre-built dashboards
└── agents/
    ├── proxmox-node/               # Proxmox agent stack
    └── dokploy-node/               # Dokploy agent stack
```

---

## 🔧 Troubleshooting

### Prometheus Target DOWN
```bash
# Cek firewall di remote node
ufw allow 9100/tcp
ufw allow 8080/tcp

# Test dari monitoring server
curl http://REMOTE_IP:9100/metrics
```

### PVE Exporter Error
```bash
# Test Proxmox API access
curl -k https://PROXMOX_IP:8006/api2/json/version \
  -u 'root@pam:YOUR_PASSWORD'
```

### No Telegram Alerts
```bash
# Test manual alert
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "status": "firing",
    "labels": {"alertname": "Test", "severity": "critical"},
    "annotations": {"summary": "Test alert"}
  }]'
```

### Loki No Data
```bash
# Check Promtail
docker compose logs promtail --tail 50

# Test Loki API
curl http://localhost:3100/ready
```

### Container Restart Loop
```bash
# Check logs
docker compose logs <service> --tail 100

# Check resources
docker stats
```

---

## 🔐 Security Recommendations

1. **Firewall Rules**
   ```bash
   # Monitoring server
   ufw allow 3000/tcp comment 'Grafana'
   ufw allow 9090/tcp comment 'Prometheus'
   ufw allow 3001/tcp comment 'Uptime Kuma'
   
   # Remote nodes (only from monitoring server)
   ufw allow from MONITORING_IP to any port 9100 comment 'Node Exporter'
   ufw allow from MONITORING_IP to any port 8080 comment 'cAdvisor'
   ```

2. **Proxmox Monitoring User**
   ```
   Datacenter → Permissions → Users → Add
   User: monitoring@pve
   Role: PVEAuditor (read-only)
   ```

3. **Change Default Passwords**
   - Grafana admin password
   - Uptime Kuma password

4. **Reverse Proxy (Optional)**
   ```nginx
   # Nginx config untuk expose Grafana via domain
   server {
       listen 80;
       server_name monitoring.yourdomain.com;
       location / {
           proxy_pass http://localhost:3000;
       }
   }
   ```

---

## 📈 Resource Requirements

### Main Stack (Monitoring Server)
- CPU: 4 cores
- RAM: 8 GB
- Disk: 50-100 GB
- OS: Ubuntu 22.04/24.04, Debian 11/12

### Agents (Per Node)
- CPU: 0.5-1 core
- RAM: 512 MB - 1 GB
- Disk: 1 GB
- Ports: 9100 (Node Exporter), 8080 (cAdvisor - Dokploy only)

---

## 🤝 Contributing

PRs welcome! Please test your changes locally before submitting.

---

## 📄 License

MIT License - feel free to use and modify for your infrastructure.

---

## 🆘 Support

Kalau ada masalah atau pertanyaan, buat issue di repo ini.

**Built with ❤️ for infrastructure monitoring**
