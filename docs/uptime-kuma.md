# Uptime Kuma — Quick Setup Guide

## Quick Start

### Step 1: Login to Uptime Kuma

1. Open your browser: **http://<MONITORING_SERVER_IP>:3001**
2. Log in with the credentials you created during initial setup
   (credentials are not stored in this repo — check your `.env` or password manager)

### Step 2: Generate API Key

1. Click **Settings** (gear icon in sidebar)
2. Select the **Security** tab
3. Scroll to the **API Keys** section
4. Click **Add API Key**
5. Fill in the form:
   - **Name**: `Setup Script`
   - **Expiry**: `Never` or `Don't Expire`
6. Click **Generate**
7. **COPY** the API Key (it only appears once!)

### Step 3: Run Setup Script

Run the script to automatically add all recommended monitors:

```bash
cd /path/to/sentinel-stack/scripts
./setup-uptime-kuma-monitors.sh <YOUR_API_KEY>
```

Replace `<YOUR_API_KEY>` with the key you copied in Step 2.

**Example:**
```bash
./setup-uptime-kuma-monitors.sh uk1_abc123def456ghi789jkl...
```

The script will add monitors for:
- ✅ Grafana
- ✅ Prometheus
- ✅ Loki
- ✅ Alertmanager
- ✅ Proxmox nodes (if `PVE_NODE1_IP` / `PVE_NODE2_IP` set in `.env`)
- ✅ Dokploy server (if `DOKPLOY_IP` set in `.env`)
- ✅ Node Exporter (all configured hosts)

> **Tip:** Make sure `PVE_NODE1_IP`, `PVE_NODE2_IP`, and `DOKPLOY_IP` are set in your `.env` file before running the script — it reads them automatically.

### Step 4: Verify Monitors

1. Go back to the browser
2. Open the dashboard
3. All monitors should appear and show **UP** (green)

---

## 📱 Setup Notifications (Optional)

### Telegram Notifications

1. Go to **Settings** → **Notifications**
2. Click **Setup Notification**
3. Fill in:
   - **Notification Type**: Telegram
   - **Friendly Name**: `Telegram Alerts`
   - **Bot Token**: Your Telegram bot token (from [@BotFather](https://t.me/BotFather))
   - **Chat ID**: Your Telegram chat ID (from [@userinfobot](https://t.me/userinfobot))
4. Click **Test** — you should receive a test message in Telegram
5. Click **Save**

---

## 🌐 Create Public Status Page

1. Go to **Status Pages**
2. Click **+ New Status Page**
3. Fill in:
   - **Name**: `Infrastructure Status`
   - **Slug**: `status` (will be accessible at `/status/status`)
4. Add monitors you want to display publicly
5. Click **Save**

**Public URL**: `http://<MONITORING_SERVER_IP>:3001/status/status`

---

## 🔧 Adding New Monitors Manually

For any new service you want to monitor:

1. Click **+ Add New Monitor**
2. Fill in:
   - **Monitor Type**: HTTP(s), TCP Port, Ping, etc.
   - **Friendly Name**: Display name
   - **URL/Host**: The target to monitor
   - **Heartbeat Interval**: Check frequency (60–120 seconds recommended)
3. Click **Save**

### Example Monitors

| Service | Type | URL/Host |
|---------|------|----------|
| Proxmox Web UI | HTTP(s) | `https://<PROXMOX_IP>:8006` |
| Node Exporter | HTTP(s) | `http://<NODE_IP>:9100/metrics` |
| Any web app | HTTP(s) | `http://<APP_IP>:<PORT>` |

---

## 🐛 Troubleshooting

### Monitors showing DOWN

```bash
# Test connectivity from the monitoring server
curl -s http://<TARGET_IP>:<PORT> | head

# Check if Uptime Kuma container can reach the target
docker exec sentinel-uptime-kuma ping -c 2 <TARGET_IP>
```

### Script fails with "unauthorized"

- Make sure the API key is correct and not expired
- Regenerate the key in Uptime Kuma Settings if needed

### Monitors added but showing pending

- Wait 1–2 heartbeat intervals (60–120 seconds)
- Check if the target is reachable from the Uptime Kuma container network

---

## 📊 Dashboard Access

Access the dashboard: **http://<MONITORING_SERVER_IP>:3001/dashboard**
