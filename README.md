# 🛡️ SentinelStack

**All-in-One System Monitoring & Uptime Platform**

Unified monitoring solution untuk Proxmox cluster, Docker containers, dan infrastructure logs dengan alerting ke Telegram.

> **Production-ready monitoring stack** with auto-discovery, centralized logging, real-time alerting, and pre-built dashboards.

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
- Telegram bot token (dari @BotFather)

### 1. Clone & Configure

```bash
git clone <repo-url> /opt/sentinel-stack
cd /opt/sentinel-stack

# Copy and edit environment variables
cp .env.example .env
nano .env
```

**Required values to configure:**
- `GRAFANA_ADMIN_PASSWORD` — Set your Grafana admin password
- `PVE_NODE1_IP` / `PVE_NODE2_IP` — Your Proxmox nodes IP addresses
- `PVE_PASSWORD` — Proxmox API password
- `DOKPLOY_IP` — Your Dokploy server IP
- `TELEGRAM_BOT_TOKEN` — Get from @BotFather on Telegram
- `TELEGRAM_CHAT_ID` — Get from @userinfobot on Telegram

### 2. Update Configuration Files

```bash
# Update Prometheus targets with your IPs
sed -i 's/PROXMOX_NODE1_IP/YOUR_PVE_NODE1_IP/g' prometheus/prometheus.yml
sed -i 's/PROXMOX_NODE2_IP/YOUR_PVE_NODE2_IP/g' prometheus/prometheus.yml
sed -i 's/DOKPLOY_IP/YOUR_DOKPLOY_IP/g' prometheus/prometheus.yml

# Update Alertmanager with Telegram credentials
sed -i "s/TELEGRAM_BOT_TOKEN/YOUR_BOT_TOKEN/g" alertmanager/alertmanager.yml
sed -i "s/TELEGRAM_CHAT_ID/YOUR_CHAT_ID/g" alertmanager/alertmanager.yml
```

### 3. Deploy Main Stack

```bash
# Interactive deployment (recommended)
./deploy.sh
# Select option 1: Deploy Main Stack

# Or manual deployment
docker compose up -d
```

### 4. Deploy Agents to Remote Nodes

**For Proxmox nodes:**
```bash
# Transfer files to Proxmox node
scp -r agents/proxmox-node/* root@PROXMOX_IP:/opt/sentinel-agent/

# SSH to node
ssh root@PROXMOX_IP
cd /opt/sentinel-agent

# Configure agent
cp .env.example .env
nano .env  # Set LOKI_URL and NODE_HOSTNAME

# Start agent
docker compose up -d
```

**For Dokploy server:**
```bash
# Transfer files to Dokploy server
scp -r agents/dokploy-node/* root@DOKPLOY_IP:/opt/sentinel-agent/

# SSH to server
ssh root@DOKPLOY_IP
cd /opt/sentinel-agent

# Configure agent
cp .env.example .env
nano .env  # Set LOKI_URL and NODE_HOSTNAME

# Start agent
docker compose up -d
```

### 5. Verify Deployment

- **Prometheus Targets:** `http://YOUR_MONITORING_IP:9090/targets` (all should be UP)
- **Grafana Dashboards:** `http://YOUR_MONITORING_IP:3000`
- **Test Telegram Alert:** Run `./deploy.sh` → option 3

> 📖 **For detailed step-by-step guide, see:** [DEPLOYMENT.md](DEPLOYMENT.md)

---

## 🎯 Access Points

| Service | URL | Default Port | Credentials |
|---------|-----|--------------|-------------|
| **Grafana** | `http://MONITORING_IP:3000` | 3000 | admin / (from .env) |
| **Prometheus** | `http://MONITORING_IP:9090` | 9090 | - |
| **Alertmanager** | `http://MONITORING_IP:9093` | 9093 | - |
| **Uptime Kuma** | `http://MONITORING_IP:3001` | 3001 | (setup on first login) |
| **Loki** | `http://MONITORING_IP:3100` | 3100 | - |
| **Status Page** | `http://MONITORING_IP:3001/status/<slug>` | - | Public (configured via Uptime Kuma) |

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

## 📝 Project Structure

```
monitoring-system/
├── docker-compose.yml              # Main stack (9 services)
├── .env.example                    # Environment template
├── .gitignore                      # Ignore secrets & runtime data
├── README.md                       # This file
├── DEPLOYMENT.md                   # Step-by-step deployment guide
├── setup.sh                        # Interactive setup script
├── deploy.sh                       # Automated deployment helper
├── prometheus/
│   ├── prometheus.yml              # Scrape config (update with your IPs)
│   └── alert-rules.yml             # 20+ alert rules
├── alertmanager/
│   └── alertmanager.yml            # Telegram alerting (update credentials)
├── loki/
│   └── loki-config.yml             # Log storage (30d retention)
├── promtail/
│   └── promtail-config.yml         # Log collection
├── grafana/
│   ├── provisioning/               # Auto-provision datasources
│   └── dashboards/                 # 4 pre-built dashboards
└── agents/
    ├── proxmox-node/               # Agent for Proxmox nodes
    │   ├── docker-compose.yml
    │   ├── .env.example            # Configure per node
    │   └── promtail-config.yml
    └── dokploy-node/               # Agent for Dokploy server
        ├── docker-compose.yml
        ├── .env.example            # Configure for your server
        └── promtail-config.yml
```

**Configuration required:**
- Update `.env` with your infrastructure details
- Update `prometheus/prometheus.yml` with your node IPs
- Update `alertmanager/alertmanager.yml` with Telegram credentials
- Configure agent `.env` files for each remote node

---

## 🔧 Troubleshooting

### Prometheus Target DOWN
```bash
# Check firewall on remote node
ufw allow from MONITORING_IP to any port 9100
ufw allow from MONITORING_IP to any port 8080

# Test from monitoring server
curl http://REMOTE_NODE_IP:9100/metrics
telnet REMOTE_NODE_IP 9100
```

### PVE Exporter Error
```bash
# Test Proxmox API access
curl -k https://PROXMOX_IP:8006/api2/json/version \
  -u 'root@pam:YOUR_PASSWORD'

# Check .env configuration
cat .env | grep PVE_PASSWORD
```

### No Telegram Alerts
```bash
# Test manual alert (automated via deploy.sh)
./deploy.sh
# Select option 3: Test Telegram Alert

# Or manual test
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "status": "firing",
    "labels": {"alertname": "Test", "severity": "critical"},
    "annotations": {"summary": "Test alert"}
  }]'

# Check alertmanager configuration
cat alertmanager/alertmanager.yml | grep -A2 bot_token

# Check logs
docker compose logs alertmanager --tail 50
```

### Loki No Data
```bash
# Check Promtail on monitoring server
docker compose logs promtail --tail 50

# Test Loki API
curl http://localhost:3100/ready

# Verify agent Promtail on remote nodes
ssh root@REMOTE_NODE_IP
cd /opt/sentinel-agent
docker compose ps
docker compose logs promtail
```

### Container Restart Loop
```bash
# Check logs
docker compose logs <service> --tail 100

# Check resources
docker stats

# Common services to check
docker compose logs grafana --tail 100
docker compose logs prometheus --tail 100
docker compose logs loki --tail 100
```

### Agent Not Sending Metrics
```bash
# On remote node, verify agent running
docker compose ps

# Test Node Exporter locally on remote node
curl http://localhost:9100/metrics | head -20

# Test from monitoring server
curl http://REMOTE_NODE_IP:9100/metrics

# Check Prometheus targets page
# Open: http://MONITORING_IP:9090/targets
```

---

## 🔐 Security Recommendations

1. **Update Default Credentials**
   - Set strong `GRAFANA_ADMIN_PASSWORD` in `.env`
   - Create dedicated Proxmox monitoring user (recommended over root):
     ```
     Datacenter → Permissions → Users → Add
     User: monitoring@pve
     Role: PVEAuditor (read-only)
     
     Then update .env:
     PVE_USER=monitoring@pve
     PVE_PASSWORD=strong_monitoring_password
     ```

2. **Firewall Configuration**
   ```bash
   # On monitoring server
   ufw allow 3000/tcp comment 'Grafana'
   ufw allow 9090/tcp comment 'Prometheus'
   ufw allow 3001/tcp comment 'Uptime Kuma'
   
   # On remote nodes (restrict to monitoring server IP only)
   ufw allow from MONITORING_SERVER_IP to any port 9100 comment 'Node Exporter'
   ufw allow from MONITORING_SERVER_IP to any port 8080 comment 'cAdvisor'
   ```

3. **Reverse Proxy Setup (Optional)**
   ```nginx
   # /etc/nginx/sites-available/monitoring
   server {
       listen 80;
       server_name monitoring.yourdomain.com;
       
       location / {
           proxy_pass http://127.0.0.1:3000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

4. **Enable SSL/TLS (Recommended for Production)**
   ```bash
   # Using Let's Encrypt with Certbot
   apt install certbot python3-certbot-nginx
   certbot --nginx -d monitoring.yourdomain.com
   
   # Auto-renewal is handled by systemd timer
   systemctl status certbot.timer
   ```

5. **Backup Strategy**
   ```bash
   # Automated daily backup (add to crontab)
   0 2 * * * cd /opt/sentinel-stack && tar -czf /backup/sentinel-$(date +\%Y\%m\%d).tar.gz .env prometheus/ alertmanager/ loki/ promtail/ grafana/
   
   # Keep last 7 days only
   0 3 * * * find /backup/sentinel-*.tar.gz -mtime +7 -delete
   ```

6. **Network Segmentation**
   - Place monitoring server on management VLAN
   - Use separate network for monitoring traffic
   - Limit external access to Grafana only

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

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes locally
4. Commit with clear messages (`git commit -m 'Add amazing feature'`)
5. Push to your branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

---

## 📄 License

MIT License - feel free to use and modify for your infrastructure.

---

## 🆘 Support & Documentation

- **Full Deployment Guide:** [DEPLOYMENT.md](DEPLOYMENT.md)
- **Issues & Questions:** Open an issue on GitHub
- **Feature Requests:** Submit via GitHub issues

---

## 📊 Monitoring Infrastructure

This stack is designed to monitor:
- ✅ Multiple Proxmox nodes in a cluster
- ✅ Dokploy server with all Docker containers
- ✅ System metrics (CPU, RAM, disk, network) from all nodes
- ✅ Centralized logs with 30-day retention
- ✅ Real-time alerts via Telegram
- ✅ Public status page for service availability

**Stack Components:**
- **Grafana** — Visualization and dashboards
- **Prometheus** — Metrics collection and storage (30d)
- **Alertmanager** — Alert routing and deduplication
- **Loki** — Log aggregation and storage (30d)
- **Promtail** — Log shipper
- **Uptime Kuma** — Uptime monitoring and status pages
- **Node Exporter** — System-level metrics
- **cAdvisor** — Container-level metrics
- **PVE Exporter** — Proxmox API metrics

---

**Built with ❤️ for infrastructure monitoring**

*SentinelStack — Production-ready monitoring for Proxmox, Docker, and beyond*
