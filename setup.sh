#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_requirements() {
    echo "Checking requirements..."
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed"
        exit 1
    fi
    if ! command -v docker compose &> /dev/null; then
        echo "Error: Docker Compose is not installed"
        exit 1
    fi
    echo "✓ Docker and Docker Compose are installed"
}

setup_env() {
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        echo "Creating .env file from .env.example..."
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        echo "✓ .env file created. Please edit it with your configuration."
        echo ""
        echo "Required values to set:"
        echo "  - TELEGRAM_BOT_TOKEN (from @BotFather)"
        echo "  - TELEGRAM_CHAT_ID (from @userinfobot)"
        echo "  - PVE_PASSWORD (Proxmox API password)"
        echo "  - GRAFANA_ADMIN_PASSWORD (change default)"
        echo ""
        read -p "Press Enter to edit .env file (or Ctrl+C to exit and edit manually)..."
        ${EDITOR:-nano} "$SCRIPT_DIR/.env"
    else
        echo "✓ .env file already exists"
    fi
}

create_directories() {
    echo "Creating required directories..."
    mkdir -p "$SCRIPT_DIR/prometheus/targets"
    mkdir -p "$SCRIPT_DIR/prometheus/rules"
    mkdir -p "$SCRIPT_DIR/alertmanager"
    mkdir -p "$SCRIPT_DIR/loki"
    mkdir -p "$SCRIPT_DIR/alloy"
    mkdir -p "$SCRIPT_DIR/caddy"
    mkdir -p "$SCRIPT_DIR/tempo"
    mkdir -p "$SCRIPT_DIR/grafana/provisioning/datasources"
    mkdir -p "$SCRIPT_DIR/grafana/provisioning/dashboards"
    mkdir -p "$SCRIPT_DIR/grafana/dashboards"
    echo "✓ Directories created"
}

render_configs() {
    echo "Rendering configs (inject secrets from .env)..."
    "$SCRIPT_DIR/scripts/render-configs.sh"
    echo "✓ Configs rendered"
}

pull_images() {
    echo "Pulling Docker images..."
    docker compose pull
    echo "✓ Images pulled"
}

start_stack() {
    echo "Starting SentinelStack..."
    docker compose up -d
    echo "✓ SentinelStack started"
}

show_status() {
    echo ""
    echo "=========================================="
    echo "  SentinelStack is running!"
    echo "=========================================="
    echo ""
    echo "Dashboards:"
    echo "  Grafana:        http://localhost:${GRAFANA_PORT:-3000}"
    echo "  Prometheus:     http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "  Alertmanager:   http://localhost:${ALERTMANAGER_PORT:-9093}"
    echo "  Uptime Kuma:    http://localhost:${UPTIME_KUMA_PORT:-3001}"
    echo ""
    echo "Default Grafana credentials:"
    echo "  Username: admin"
    echo "  Password: (from GRAFANA_ADMIN_PASSWORD in .env)"
    echo ""
    echo "Pre-built dashboards available:"
    echo "  - Proxmox Cluster Overview"
    echo "  - Docker Container Overview"
    echo "  - Node System Overview"
    echo "  - Logs Explorer"
    echo ""
    echo "To stop: docker compose down"
    echo "To view logs: docker compose logs -f"
    echo ""
}

main() {
    echo "=========================================="
    echo "  SentinelStack Setup"
    echo "=========================================="
    echo ""
    
    check_requirements
    setup_env
    create_directories
    render_configs
    pull_images
    start_stack
    show_status
}

main "$@"
