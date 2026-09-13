# 🛡️ SentinelStack - Deployment Checklist

## ✅ Pre-Deployment Checklist

### 1. Update `.env` file
```bash
cd /home/augie/Projek/monitoring-system
nano .env
```

**Required values:**
- [ ] `PVE_PASSWORD` — Proxmox root password
- [ ] `TELEGRAM_BOT_TOKEN` — From @BotFather
- [ ] `TELEGRAM_CHAT_ID` — From @userinfobot
- [ ] `GRAFANA_ADMIN_PASSWORD` — Change if needed (default: REDACTED_GRAFANA_PASSWORD)

---

## 📋 Deployment Steps

### Step 1: Deploy Main Stack (Monitoring Server)

**Target:** 192.168.18.104

```bash
# Transfer project ke monitoring server
scp -r /home/augie/Projek/monitoring-system root@192.168.18.104:/opt/sentinel-stack/

# SSH ke monitoring server
ssh root@192.168.18.104
cd /opt/sentinel-stack

# Install Docker (jika belum)
curl -fsSL https://get.docker.com | sh

# Run deployment script
./deploy.sh
# Pilih option 1: Deploy Main Stack
```

**Verify:**
- Open http://192.168.18.104:3000 (Grafana)
- Login: admin / REDACTED_GRAFANA_PASSWORD
- Check http://192.168.18.104:9090/targets (Prometheus)

---

### Step 2: Deploy Agent - Proxmox pve (192.168.18.254)

```bash
# Dari local machine
scp -r /home/augie/Projek/monitoring-system/agents/proxmox-node/* root@192.168.18.254:/opt/sentinel-agent/
scp /home/augie/Projek/monitoring-system/agents/proxmox-node/.env.pve root@192.168.18.254:/opt/sentinel-agent/.env

# SSH ke pve
ssh root@192.168.18.254
cd /opt/sentinel-agent

# Install Docker (jika belum)
apt update && apt install -y docker.io docker-compose-plugin

# Start agent
docker compose up -d

# Verify
docker compose ps
curl http://localhost:9100/metrics | head -20
```

---

### Step 3: Deploy Agent - Proxmox pve-1 (192.168.18.253)

```bash
# Dari local machine
scp -r /home/augie/Projek/monitoring-system/agents/proxmox-node/* root@192.168.18.253:/opt/sentinel-agent/
scp /home/augie/Projek/monitoring-system/agents/proxmox-node/.env.pve-1 root@192.168.18.253:/opt/sentinel-agent/.env

# SSH ke pve-1
ssh root@192.168.18.253
cd /opt/sentinel-agent

# Install Docker (jika belum)
apt update && apt install -y docker.io docker-compose-plugin

# Start agent
docker compose up -d

# Verify
docker compose ps
curl http://localhost:9100/metrics | head -20
```

---

### Step 4: Deploy Agent - Dokploy Master (192.168.18.150)

```bash
# Dari local machine
scp -r /home/augie/Projek/monitoring-system/agents/dokploy-node/* root@192.168.18.150:/opt/sentinel-agent/
scp /home/augie/Projek/monitoring-system/agents/dokploy-node/.env.dokploy root@192.168.18.150:/opt/sentinel-agent/.env

# SSH ke dokploy
ssh root@192.168.18.150
cd /opt/sentinel-agent

# Docker already installed via Dokploy
# Start agent
docker compose up -d

# Verify
docker compose ps
curl http://localhost:9100/metrics | head -20
curl http://localhost:8080/metrics | head -20
```

---

### Step 5: Verify All Targets

Open: **http://192.168.18.104:9090/targets**

Expected targets (all should be **UP**):

| Job | Target | Status |
|-----|--------|--------|
| prometheus | localhost:9090 | ✅ UP |
| grafana | grafana:3000 | ✅ UP |
| alertmanager | alertmanager:9093 | ✅ UP |
| loki | loki:3100 | ✅ UP |
| uptime-kuma | uptime-kuma:3001 | ✅ UP |
| node-exporter-local | node-exporter:9100 | ✅ UP |
| cadvisor-local | cadvisor:8080 | ✅ UP |
| pve-exporter | pve-exporter:9221 | ✅ UP |
| node-exporter-remote | 192.168.18.254:9100 | ✅ UP |
| node-exporter-remote | 192.168.18.253:9100 | ✅ UP |
| node-exporter-remote | 192.168.18.150:9100 | ✅ UP |
| cadvisor-remote-dokploy | 192.168.18.150:8080 | ✅ UP |

**Troubleshooting if DOWN:**
```bash
# Cek firewall di remote node
ufw allow 9100/tcp
ufw allow 8080/tcp

# Test dari monitoring server
curl http://192.168.18.254:9100/metrics
```

---

### Step 6: Test Telegram Alerting

```bash
# Dari monitoring server
cd /opt/sentinel-stack
./deploy.sh
# Pilih option 3: Test Telegram Alert
```

Atau manual:
```bash
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "status": "firing",
    "labels": {
      "alertname": "TestAlert",
      "severity": "critical",
      "category": "test",
      "instance": "test-instance"
    },
    "annotations": {
      "summary": "🧪 Test alert from SentinelStack",
      "description": "If you see this in Telegram, alerting works!"
    }
  }]'
```

You should receive message di Telegram dalam 30 detik.

---

### Step 7: Setup Uptime Kuma

1. Open **http://192.168.18.104:3001**
2. Create admin account (first time)
3. Add monitors:

**Proxmox pve:**
- Type: TCP Port
- Host: 192.168.18.254
- Port: 8006
- Name: Proxmox pve

**Proxmox pve-1:**
- Type: TCP Port
- Host: 192.168.18.253
- Port: 8006
- Name: Proxmox pve-1

**Dokploy:**
- Type: HTTP(s)
- URL: http://192.168.18.150:3000
- Name: Dokploy Master

4. Setup Telegram notification:
   - Settings → Notifications → Setup Notification
   - Type: Telegram
   - Bot Token: (sama dengan di .env)
   - Chat ID: (sama dengan di .env)
   - Test → Save

5. Create Status Page:
   - Status Pages → + New Status Page
   - Name: Infrastructure Status
   - Slug: status
   - Add all monitors
   - Save
   - Public URL: http://192.168.18.104:3001/status/status

---

## 🔍 Post-Deployment Verification

### Grafana Dashboards
1. Open http://192.168.18.104:3000
2. Login: admin / REDACTED_GRAFANA_PASSWORD
3. Navigate to: ☰ Menu → Dashboards → SentinelStack/
4. Check each dashboard:
   - ✅ Proxmox Cluster Overview
   - ✅ Docker Container Overview
   - ✅ Node System Overview
   - ✅ Logs Explorer

### Prometheus Metrics
Visit http://192.168.18.104:9090/graph

Test queries:
```promql
# CPU usage per node
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Proxmox VMs count
count(pve_vm_info)

# Docker containers running
count(container_tasks_state{state="running"} > 0)
```

### Loki Logs
In Grafana:
1. Go to Explore (compass icon)
2. Select **Loki** datasource
3. Query: `{job="docker-logs"}`
4. You should see logs from Docker containers

---

## 🔥 Common Issues & Fixes

### Issue: Prometheus target DOWN
```bash
# On remote node
ufw allow from 192.168.18.104 to any port 9100
ufw allow from 192.168.18.104 to any port 8080

# Test connectivity from monitoring server
telnet 192.168.18.254 9100
```

### Issue: PVE Exporter error
```bash
# Test Proxmox API
curl -k https://192.168.18.254:8006/api2/json/version \
  -u 'root@pam:YOUR_PASSWORD'

# Check .env has correct PVE_PASSWORD
cat /opt/sentinel-stack/.env | grep PVE_PASSWORD
```

### Issue: No Telegram alerts
```bash
# Check alertmanager config
cat /opt/sentinel-stack/alertmanager/alertmanager.yml | grep bot_token

# Check alertmanager logs
cd /opt/sentinel-stack
docker compose logs alertmanager --tail 50
```

### Issue: Container restart loop
```bash
cd /opt/sentinel-stack
docker compose logs <service-name> --tail 100

# Example:
docker compose logs grafana --tail 100
```

---

## 📊 Access Summary

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://192.168.18.104:3000 | admin / REDACTED_GRAFANA_PASSWORD |
| Prometheus | http://192.168.18.104:9090 | - |
| Alertmanager | http://192.168.18.104:9093 | - |
| Uptime Kuma | http://192.168.18.104:3001 | (setup saat first login) |
| Status Page | http://192.168.18.104:3001/status/status | Public |

---

## 🛠️ Maintenance Commands

```bash
# View status
cd /opt/sentinel-stack
docker compose ps

# View logs
docker compose logs -f

# Restart service
docker compose restart grafana

# Update all services
docker compose pull
docker compose up -d

# Stop stack
docker compose down

# Backup
tar -czf sentinel-backup-$(date +%Y%m%d).tar.gz \
  .env prometheus/ alertmanager/ loki/ promtail/ grafana/
```

---

## ✅ Deployment Complete!

Your infrastructure is now monitored by SentinelStack:
- ✅ 2 Proxmox nodes monitored
- ✅ 1 Dokploy server + all containers monitored
- ✅ Centralized logs (30 days)
- ✅ Telegram alerts configured
- ✅ 4 pre-built Grafana dashboards
- ✅ Public status page

**Next:** Monitor dashboards and wait for metrics to populate (2-5 minutes).
