# Agent Setup Guide

SentinelStack uses lightweight agents to collect metrics and logs from remote nodes.

---

## Overview

| Agent Type | Install Method | Use For |
|-----------|---------------|---------|
| **Proxmox Node** | systemd native | Proxmox VE hosts |
| **Docker Host** | Docker Compose | Any Docker host (Dokploy, Portainer, etc.) |

Both agents install:
- **node_exporter** — system metrics (CPU, RAM, disk, network)
- **Grafana Alloy** — log shipping to Loki

---

## Proxmox Node Agent

### What it installs

| Component | Type | Port |
|-----------|------|------|
| node_exporter | systemd service | 9100 |
| Grafana Alloy | systemd service | — |

### Install

```bash
# From your monitoring server, transfer the installer:
scp agents/proxmox-node/install.sh root@<PROXMOX_IP>:/tmp/

# On the Proxmox host:
ssh root@<PROXMOX_IP>
chmod +x /tmp/install.sh

# Run with your monitoring server IP:
MONITORING_SERVER=<MONITORING_SERVER_IP> NODE_HOSTNAME=pve-1 /tmp/install.sh
```

**Environment variables:**

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MONITORING_SERVER` | ✅ Yes | — | IP of your monitoring server |
| `NODE_HOSTNAME` | No | `$(hostname)` | Label for this node in Grafana |

### Verify

```bash
systemctl status node_exporter alloy
curl http://localhost:9100/metrics | head -20
```

### Uninstall

```bash
scp agents/proxmox-node/uninstall.sh root@<PROXMOX_IP>:/tmp/
ssh root@<PROXMOX_IP> 'chmod +x /tmp/uninstall.sh && /tmp/uninstall.sh'
```

---

## Docker Host Agent

### What it installs

| Component | Type | Port |
|-----------|------|------|
| node_exporter | systemd service | 9100 |
| Grafana Alloy | Docker container | — |

> node_exporter is installed via the same `install.sh` as Proxmox nodes.
> Grafana Alloy runs as a Docker container for Docker log collection.

### Install

**Step 1 — Install node_exporter:**

```bash
# On the Docker host:
MONITORING_SERVER=<MONITORING_SERVER_IP> bash -s < agents/proxmox-node/install.sh
```

**Step 2 — Install Alloy container:**

```bash
# From monitoring server, transfer agent files:
scp -r agents/dokploy-node/* root@<DOCKER_HOST_IP>:/opt/sentinel-agent/

# On the Docker host:
cd /opt/sentinel-agent
cp .env.example .env
nano .env
```

**Configure `.env`:**

```env
LOKI_URL=http://<MONITORING_SERVER_IP>:3100/loki/api/v1/push
NODE_HOSTNAME=dokploy
```

**Start:**

```bash
docker compose up -d
```

### Verify

```bash
docker compose ps
curl http://localhost:9100/metrics | head -20
```

---

## Register the Node in Prometheus

After installing agents, add the node to Prometheus:

```bash
# On the monitoring server:
nano prometheus/targets/node-exporters.yml
```

```yaml
- targets: ['<NODE_IP>:9100']
  labels:
    host_type: 'proxmox'   # or 'remote'
    node_name: 'my-node'
```

Prometheus auto-reloads within ~5 seconds.

For Proxmox nodes, also add to `prometheus/targets/pve-exporters.yml`:

```yaml
- targets: ['<PROXMOX_IP>']
  labels:
    host_type: 'proxmox'
    node_name: 'my-pve-node'
```

---

## Firewall Rules

Allow these ports from the monitoring server:

```bash
# On the remote node:
ufw allow from <MONITORING_SERVER_IP> to any port 9100   # node_exporter
ufw allow from <MONITORING_SERVER_IP> to any port 8080   # cAdvisor (Docker hosts)
```

---

## Troubleshooting

**node_exporter not starting:**
```bash
journalctl -u node_exporter -n 50
```

**Alloy not shipping logs:**
```bash
# Proxmox (systemd):
journalctl -u alloy -n 50

# Docker host:
docker compose logs alloy --tail 50
```

**Verify Loki URL is correct:**
```bash
# From the agent node:
curl -s http://<MONITORING_SERVER_IP>:3100/ready
```
