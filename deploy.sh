#!/bin/bash
# SentinelStack Deployment Script
# Automated deployment untuk monitoring server dan semua agents

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header "SentinelStack Deployment Helper"

echo "Infrastructure IP Configuration:"
echo "  • Monitoring Server: 192.168.18.104"
echo "  • Proxmox pve:       192.168.18.254"
echo "  • Proxmox pve-1:     192.168.18.253"
echo "  • Dokploy Master:    192.168.18.150"
echo ""

# Check if .env exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    print_error ".env file not found!"
    echo "Please update the following in .env:"
    echo "  - PVE_PASSWORD (Proxmox password)"
    echo "  - TELEGRAM_BOT_TOKEN (from @BotFather)"
    echo "  - TELEGRAM_CHAT_ID (from @userinfobot)"
    echo "  - GRAFANA_ADMIN_PASSWORD (change default if needed)"
    exit 1
fi

# Check for required env vars
source "$SCRIPT_DIR/.env"

if [[ "$TELEGRAM_BOT_TOKEN" == "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]]; then
    print_warning "TELEGRAM_BOT_TOKEN not set in .env"
    read -p "Enter your Telegram Bot Token: " BOT_TOKEN
    sed -i "s/YOUR_TELEGRAM_BOT_TOKEN_HERE/$BOT_TOKEN/" "$SCRIPT_DIR/.env"
fi

if [[ "$TELEGRAM_CHAT_ID" == "YOUR_TELEGRAM_CHAT_ID_HERE" ]]; then
    print_warning "TELEGRAM_CHAT_ID not set in .env"
    read -p "Enter your Telegram Chat ID: " CHAT_ID
    sed -i "s/YOUR_TELEGRAM_CHAT_ID_HERE/$CHAT_ID/" "$SCRIPT_DIR/.env"
fi

if [[ "$PVE_PASSWORD" == "YOUR_PROXMOX_PASSWORD_HERE" ]]; then
    print_warning "PVE_PASSWORD not set in .env"
    read -sp "Enter your Proxmox password: " PVE_PASS
    echo ""
    sed -i "s/YOUR_PROXMOX_PASSWORD_HERE/$PVE_PASS/" "$SCRIPT_DIR/.env"
fi

# Reload .env after updates
source "$SCRIPT_DIR/.env"

# Update alertmanager with Telegram credentials
print_header "Updating Alertmanager Configuration"
sed -i "s/TELEGRAM_BOT_TOKEN/$TELEGRAM_BOT_TOKEN/g" "$SCRIPT_DIR/alertmanager/alertmanager.yml"
sed -i "s/TELEGRAM_CHAT_ID/$TELEGRAM_CHAT_ID/g" "$SCRIPT_DIR/alertmanager/alertmanager.yml"
print_success "Alertmanager configured with Telegram credentials"

echo ""
echo "Deployment Options:"
echo "  1) Deploy Main Stack (Monitoring Server - 192.168.18.104)"
echo "  2) Generate Agent Deployment Commands"
echo "  3) Test Telegram Alert"
echo "  4) View Stack Status"
echo "  5) Exit"
echo ""

read -p "Select option [1-5]: " OPTION

case $OPTION in
    1)
        print_header "Deploying Main Stack"
        
        if ! command -v docker &> /dev/null; then
            print_error "Docker is not installed"
            exit 1
        fi
        
        print_success "Pulling Docker images..."
        docker compose pull
        
        print_success "Starting SentinelStack..."
        docker compose up -d
        
        echo ""
        print_success "SentinelStack is running!"
        echo ""
        echo "Access Points:"
        echo "  • Grafana:        http://192.168.18.104:3000"
        echo "  • Prometheus:     http://192.168.18.104:9090"
        echo "  • Alertmanager:   http://192.168.18.104:9093"
        echo "  • Uptime Kuma:    http://192.168.18.104:3001"
        echo ""
        echo "Default Grafana Login:"
        echo "  Username: admin"
        echo "  Password: $GRAFANA_ADMIN_PASSWORD"
        echo ""
        echo "Next steps:"
        echo "  1. Wait 2-3 minutes for all services to be ready"
        echo "  2. Deploy agents to remote nodes (option 2)"
        echo "  3. Check Prometheus targets: http://192.168.18.104:9090/targets"
        ;;
        
    2)
        print_header "Agent Deployment Commands"
        
        echo "═══════════════════════════════════════════"
        echo "PROXMOX NODE: pve (192.168.18.254)"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "# SSH ke pve node"
        echo "ssh root@192.168.18.254"
        echo ""
        echo "# Install Docker (jika belum)"
        echo "apt update && apt install -y docker.io docker-compose-plugin"
        echo ""
        echo "# Buat folder agent"
        echo "mkdir -p /opt/sentinel-agent"
        echo ""
        echo "# Exit SSH, lalu transfer files dari local:"
        echo "scp -r $SCRIPT_DIR/agents/proxmox-node/* root@192.168.18.254:/opt/sentinel-agent/"
        echo "scp $SCRIPT_DIR/agents/proxmox-node/.env.pve root@192.168.18.254:/opt/sentinel-agent/.env"
        echo ""
        echo "# SSH lagi dan start agent"
        echo "ssh root@192.168.18.254"
        echo "cd /opt/sentinel-agent"
        echo "docker compose up -d"
        echo ""
        
        echo "═══════════════════════════════════════════"
        echo "PROXMOX NODE: pve-1 (192.168.18.253)"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "# SSH ke pve-1 node"
        echo "ssh root@192.168.18.253"
        echo ""
        echo "# Install Docker (jika belum)"
        echo "apt update && apt install -y docker.io docker-compose-plugin"
        echo ""
        echo "# Buat folder agent"
        echo "mkdir -p /opt/sentinel-agent"
        echo ""
        echo "# Exit SSH, lalu transfer files dari local:"
        echo "scp -r $SCRIPT_DIR/agents/proxmox-node/* root@192.168.18.253:/opt/sentinel-agent/"
        echo "scp $SCRIPT_DIR/agents/proxmox-node/.env.pve-1 root@192.168.18.253:/opt/sentinel-agent/.env"
        echo ""
        echo "# SSH lagi dan start agent"
        echo "ssh root@192.168.18.253"
        echo "cd /opt/sentinel-agent"
        echo "docker compose up -d"
        echo ""
        
        echo "═══════════════════════════════════════════"
        echo "DOKPLOY SERVER: dokploy-master (192.168.18.150)"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "# SSH ke dokploy server"
        echo "ssh root@192.168.18.150"
        echo ""
        echo "# Buat folder agent (Docker sudah terinstall dari Dokploy)"
        echo "mkdir -p /opt/sentinel-agent"
        echo ""
        echo "# Exit SSH, lalu transfer files dari local:"
        echo "scp -r $SCRIPT_DIR/agents/dokploy-node/* root@192.168.18.150:/opt/sentinel-agent/"
        echo "scp $SCRIPT_DIR/agents/dokploy-node/.env.dokploy root@192.168.18.150:/opt/sentinel-agent/.env"
        echo ""
        echo "# SSH lagi dan start agent"
        echo "ssh root@192.168.18.150"
        echo "cd /opt/sentinel-agent"
        echo "docker compose up -d"
        echo ""
        
        echo "═══════════════════════════════════════════"
        echo "VERIFICATION"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "After deploying all agents, verify targets:"
        echo "  http://192.168.18.104:9090/targets"
        echo ""
        echo "All targets should show status UP (green)."
        ;;
        
    3)
        print_header "Testing Telegram Alert"
        
        if ! docker compose ps | grep -q "sentinel-alertmanager.*Up"; then
            print_error "Alertmanager is not running. Deploy main stack first (option 1)"
            exit 1
        fi
        
        echo "Sending test alert to Telegram..."
        curl -X POST http://localhost:9093/api/v1/alerts \
          -H "Content-Type: application/json" \
          -d '[{
            "status": "firing",
            "labels": {
              "alertname": "SentinelStackTest",
              "severity": "critical",
              "category": "test",
              "instance": "monitoring-server"
            },
            "annotations": {
              "summary": "🧪 Test Alert dari SentinelStack",
              "description": "Jika kamu menerima message ini di Telegram, alerting sudah berfungsi dengan baik!"
            }
          }]'
        
        echo ""
        echo ""
        print_success "Test alert sent!"
        echo "Check your Telegram. You should receive a message within 30 seconds."
        ;;
        
    4)
        print_header "Stack Status"
        
        if ! command -v docker &> /dev/null; then
            print_error "Docker is not installed"
            exit 1
        fi
        
        docker compose ps
        echo ""
        echo "Logs (last 20 lines):"
        docker compose logs --tail 20
        ;;
        
    5)
        echo "Exiting..."
        exit 0
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac
