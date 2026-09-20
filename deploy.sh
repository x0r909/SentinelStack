#!/bin/bash
# SentinelStack Deployment Helper
# Automated deployment for monitoring stack and agent setup guide

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Load .env if present
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
    set +a
fi

LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

print_header "SentinelStack Deployment Helper"

echo "Current server: ${LOCAL_IP}"
echo ""

# Check if .env exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    print_error ".env file not found!"
    echo "Please run: cp .env.example .env && nano .env"
    echo "Required values:"
    echo "  - PVE_USER / PVE_PASSWORD (Proxmox API credentials)"
    echo "  - TELEGRAM_BOT_TOKEN (from @BotFather)"
    echo "  - TELEGRAM_CHAT_ID (from @userinfobot)"
    echo "  - GRAFANA_ADMIN_PASSWORD"
    echo "  - PROM_USER / PROM_BCRYPT_HASH"
    exit 1
fi

# Render configs from templates
print_header "Rendering Configs"
if ! "$SCRIPT_DIR/scripts/render-configs.sh"; then
    print_error "Config rendering failed. Fix .env and retry."
    exit 1
fi
print_success "Configs rendered"

echo ""
echo "Deployment Options:"
echo "  1) Deploy Main Stack (this server)"
echo "  2) Show Agent Deployment Guide"
echo "  3) Test Telegram Alert"
echo "  4) View Stack Status"
echo "  5) Exit"
echo ""

read -p "Select option [1-5]: " OPTION

case $OPTION in
    1)
        print_header "Deploying Main Stack"

        if ! command -v docker &> /dev/null; then
            print_error "Docker is not installed. Install with: curl -fsSL https://get.docker.com | sh"
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
        echo "  • Grafana:        ${GRAFANA_ROOT_URL:-http://localhost:3000}"
        echo "  • Prometheus:     https://${PROMETHEUS_DOMAIN:-prometheus.local}"
        echo "  • Alertmanager:   https://${ALERTS_DOMAIN:-alerts.local}"
        echo "  • Uptime Kuma:    http://${LOCAL_IP}:3001"
        echo ""
        echo "Next steps:"
        echo "  1. Wait 2-3 minutes for all services to be ready"
        echo "  2. Edit prometheus/targets/*.yml with your node IPs"
        echo "  3. Deploy agents to remote nodes (option 2)"
        ;;

    2)
        print_header "Agent Deployment Guide"

        echo "═══════════════════════════════════════════"
        echo "PROXMOX NODES (systemd native install)"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "# On each Proxmox host, run:"
        echo "MONITORING_SERVER=${LOCAL_IP} NODE_HOSTNAME=<node-name> bash -s < $SCRIPT_DIR/agents/proxmox-node/install.sh"
        echo ""
        echo "# Or copy and run manually:"
        echo "scp $SCRIPT_DIR/agents/proxmox-node/install.sh root@<NODE_IP>:/tmp/"
        echo "ssh root@<NODE_IP> 'chmod +x /tmp/install.sh && MONITORING_SERVER=${LOCAL_IP} NODE_HOSTNAME=<node-name> /tmp/install.sh'"
        echo ""

        echo "═══════════════════════════════════════════"
        echo "DOCKER HOSTS (e.g. Dokploy)"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "# On the remote host:"
        echo "mkdir -p /opt/sentinel-agent"
        echo ""
        echo "# From this server, transfer files:"
        echo "scp -r $SCRIPT_DIR/agents/dokploy-node/* root@<NODE_IP>:/opt/sentinel-agent/"
        echo ""
        echo "# On the remote host, configure and start:"
        echo "cd /opt/sentinel-agent"
        echo "cp .env.example .env && nano .env  # set LOKI_URL=http://${LOCAL_IP}:3100"
        echo "docker compose up -d"
        echo ""

        echo "═══════════════════════════════════════════"
        echo "VERIFICATION"
        echo "═══════════════════════════════════════════"
        echo ""
        echo "After deploying agents, check targets:"
        echo "  https://${PROMETHEUS_DOMAIN:-prometheus.local}/targets"
        echo ""
        echo "Or from this server:"
        echo "  docker compose exec prometheus wget -qO- http://localhost:9090/api/v1/targets | grep -E 'scrapeUrl|health'"
        echo ""

        echo "Don't forget to update prometheus/targets/*.yml with your node IPs!"
        echo ""
        ;;

    3)
        print_header "Testing Telegram Alert"

        if ! docker compose ps 2>/dev/null | grep -q "sentinel-alertmanager.*Up"; then
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
              "summary": "Test Alert from SentinelStack",
              "description": "If you received this message in Telegram, alerting is working correctly!"
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
