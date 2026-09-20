#!/bin/bash

# Uptime Kuma Monitor Setup Script
# Adds recommended monitors to Uptime Kuma via API
#
# Usage:
#   ./setup-uptime-kuma-monitors.sh <API_KEY> [KUMA_URL]
#
# Environment variables (loaded from ../.env if present):
#   PVE_NODE1_IP   - Proxmox node 1 IP
#   PVE_NODE2_IP   - Proxmox node 2 IP
#   DOKPLOY_IP     - Dokploy server IP
#   LOKI_URL       - Loki server URL (used to derive monitoring server IP)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load .env from parent directory if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/../.env"
    set +a
fi

# Derive monitoring server IP from GRAFANA_ROOT_URL or LOKI_URL, fallback to localhost
MONITORING_IP=$(echo "${GRAFANA_ROOT_URL:-http://localhost:3000}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || echo "localhost")
KUMA_URL="${2:-http://${MONITORING_IP}:3001}"
API_KEY="${1:-}"

echo "════════════════════════════════════════════════════════════════"
echo "  Uptime Kuma - Monitor Setup Script"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check if API key is provided
if [ -z "$API_KEY" ]; then
    echo -e "${YELLOW}⚠  API Key not provided!${NC}"
    echo ""
    echo "How to get your API Key:"
    echo "1. Login to Uptime Kuma: $KUMA_URL"
    echo "2. Go to Settings > Security"
    echo "3. Scroll to 'API Keys'"
    echo "4. Click 'Add API Key'"
    echo "5. Name: 'Setup Script', Expiry: Never"
    echo "6. Copy the generated API Key"
    echo ""
    echo "Usage:"
    echo "  $0 <API_KEY> [KUMA_URL]"
    echo ""
    echo "Example:"
    echo "  $0 uk1_abc123def456..."
    echo "  $0 uk1_abc123def456... http://192.168.1.50:3001"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} API Key detected"
echo -e "${GREEN}✓${NC} Uptime Kuma URL: $KUMA_URL"
echo ""

# Function to add monitor
add_monitor() {
    local name="$1"
    local type="$2"
    local url="$3"
    local interval="$4"
    local keyword="${5:-}"
    local ignoreTls="${6:-false}"

    echo -n "Adding monitor: $name ... "

    payload=$(cat <<EOF
{
  "type": "$type",
  "name": "$name",
  "url": "$url",
  "interval": $interval,
  "retryInterval": 60,
  "maxretries": 3,
  "notificationIDList": [],
  "upsideDown": false,
  "maxredirects": 10,
  "accepted_statuscodes": ["200-299"],
  "dns_resolve_type": "A",
  "dns_resolve_server": "1.1.1.1",
  "proxyId": null,
  "method": "GET",
  "body": null,
  "headers": null,
  "authMethod": null,
  "keyword": "$keyword",
  "ignoreTls": $ignoreTls,
  "active": true
}
EOF
)

    response=$(curl -s -X POST "$KUMA_URL/api/monitor" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$payload")

    if echo "$response" | grep -q '"ok":true'; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo "  Response: $response"
    fi
}

echo "Adding monitoring targets..."
echo "────────────────────────────────────────────────────────────────"

# Core Services (internal Docker network)
add_monitor "Grafana" "http" "http://grafana:3000" 60
add_monitor "Prometheus" "http" "http://prometheus:9090/-/healthy" 60
add_monitor "Loki" "http" "http://loki:3100/ready" 60
add_monitor "Alertmanager" "http" "http://alertmanager:9093/-/healthy" 60

# Proxmox Nodes (if IPs configured)
if [ -n "${PVE_NODE1_IP:-}" ]; then
    add_monitor "Proxmox pve-1" "http" "https://${PVE_NODE1_IP}:8006" 120 "" true
    add_monitor "Node Exporter (pve-1)" "http" "http://${PVE_NODE1_IP}:9100/metrics" 120 "node_"
fi

if [ -n "${PVE_NODE2_IP:-}" ]; then
    add_monitor "Proxmox pve-2" "http" "https://${PVE_NODE2_IP}:8006" 120 "" true
    add_monitor "Node Exporter (pve-2)" "http" "http://${PVE_NODE2_IP}:9100/metrics" 120 "node_"
fi

# Dokploy (if IP configured)
if [ -n "${DOKPLOY_IP:-}" ]; then
    add_monitor "Dokploy Server" "http" "http://${DOKPLOY_IP}:3000" 120
    add_monitor "Node Exporter (Dokploy)" "http" "http://${DOKPLOY_IP}:9100/metrics" 120 "node_"
fi

# Local Node Exporter
add_monitor "Node Exporter (Monitoring)" "http" "http://node-exporter:9100/metrics" 120 "node_"

echo "────────────────────────────────────────────────────────────────"
echo ""
echo -e "${GREEN}✓ Monitor setup complete!${NC}"
echo ""
echo "Check monitors at: $KUMA_URL/dashboard"
echo ""
echo "Tip: Set PVE_NODE1_IP, PVE_NODE2_IP, DOKPLOY_IP in your .env to add remote node monitors automatically."
echo ""
