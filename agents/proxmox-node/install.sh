#!/bin/bash
# SentinelStack Agent - Native Install Script for Proxmox Host
# Installs node_exporter and Grafana Alloy as systemd services directly on the host

set -e

NODE_EXPORTER_VERSION="1.8.2"
ALLOY_VERSION="0.2.0"
MONITORING_SERVER="${MONITORING_SERVER:-}"
NODE_HOSTNAME="${NODE_HOSTNAME:-$(hostname)}"

# Require monitoring server IP
if [ -z "$MONITORING_SERVER" ]; then
    echo "Error: MONITORING_SERVER is required."
    echo "Usage: MONITORING_SERVER=<monitoring-server-ip> NODE_HOSTNAME=<name> $0"
    exit 1
fi
LOKI_URL="http://${MONITORING_SERVER}:3100/loki/api/v1/push"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================"
    echo "  SentinelStack Agent Installation"
    echo "  Host: $NODE_HOSTNAME"
    echo "========================================"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        exit 1
    fi
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    local missing=()
    
    if ! command -v wget &>/dev/null; then
        missing+=("wget")
    fi
    
    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "Missing dependencies: ${missing[*]}"
        print_status "Attempting to install..."
        apt-get update -qq 2>/dev/null || true
        apt-get install -y -qq "${missing[@]}" > /dev/null 2>&1 || true
    fi
    
    if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
        print_error "Neither wget nor curl available. Please install manually."
        exit 1
    fi
    
    print_status "Dependencies OK"
}

create_user() {
    if id "node_exporter" &>/dev/null; then
        print_warning "User 'node_exporter' already exists"
    else
        useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
        print_status "Created user 'node_exporter'"
    fi
}

install_node_exporter() {
    print_status "Installing node_exporter ${NODE_EXPORTER_VERSION}..."
    
    cd /tmp
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
    
    if command -v wget &>/dev/null; then
        wget -q "$NODE_EXPORTER_URL" -O node_exporter.tar.gz
    else
        curl -sL "$NODE_EXPORTER_URL" -o node_exporter.tar.gz
    fi
    
    tar xzf node_exporter.tar.gz
    
    cp node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter /usr/local/bin/
    chmod +x /usr/local/bin/node_exporter
    chown node_exporter:node_exporter /usr/local/bin/node_exporter
    
    rm -rf node_exporter.tar.gz node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}
    
    print_status "node_exporter binary installed"
}

create_node_exporter_service() {
    print_status "Creating node_exporter systemd service..."
    
    cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter for Prometheus
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/bin/node_exporter \
    --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/) \
    --collector.netclass.ignored-devices=^(veth.*)$$

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    
    print_status "node_exporter service started"
}

install_alloy() {
    print_status "Installing Grafana Alloy ${ALLOY_VERSION}..."

    cd /tmp

    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    ALLOY_URL="https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-amd64.zip"

    if [ "$ARCH" = "arm64" ]; then
        ALLOY_URL="https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-arm64.zip"
    fi

    if command -v wget &>/dev/null; then
        wget -q "$ALLOY_URL" -O alloy.zip
    else
        curl -sL "$ALLOY_URL" -o alloy.zip
    fi

    if ! command -v unzip &>/dev/null; then
        apt-get install -y -qq unzip > /dev/null 2>&1 || true
    fi

    unzip -q -o alloy.zip 2>/dev/null || true

    if [ -f alloy-linux-amd64 ] || [ -f alloy-linux-arm64 ]; then
        mv alloy-linux-* /usr/local/bin/alloy
    elif [ -f alloy ]; then
        mv alloy /usr/local/bin/alloy
    else
        print_error "alloy binary not found after extraction"
        ls -la /tmp/
        exit 1
    fi

    chmod +x /usr/local/bin/alloy

    rm -f alloy.zip

    print_status "alloy binary installed"
}

create_alloy_config() {
    print_status "Creating Alloy configuration..."

    mkdir -p /etc/alloy

    cat > /etc/alloy/config.alloy << EOF
// SentinelStack Agent - Alloy config (Proxmox node: ${NODE_HOSTNAME})

loki.write "remote" {
  endpoint {
    url = "${LOKI_URL}"
  }
}

// ============================================
// SYSTEM LOGS
// ============================================

loki.source.file "varlogs" {
  targets = [
    { __path__ = "/var/log/*log", job = "varlogs", host = "${NODE_HOSTNAME}" },
  ]
  forward_to    = [loki.process.syslog.receiver]
  tail_from_end = false
}

loki.source.file "pvefirewall" {
  targets = [
    { __path__ = "/var/log/pve-firewall.log", job = "pve-firewall", host = "${NODE_HOSTNAME}" },
  ]
  forward_to    = [loki.process.rfc3339.receiver]
  tail_from_end = true
}

loki.source.file "pveproxy" {
  targets = [
    { __path__ = "/var/log/pveproxy/access.log", job = "pveproxy-access", host = "${NODE_HOSTNAME}" },
  ]
  forward_to    = [loki.process.pveproxy.receiver]
  tail_from_end = true
}

loki.source.file "pvecluster" {
  targets = [
    { __path__ = "/var/log/pve-cluster.log", job = "pve-cluster", host = "${NODE_HOSTNAME}" },
  ]
  forward_to    = [loki.process.syslog.receiver]
  tail_from_end = true
}

// ============================================
// PIPELINES
// ============================================

// Classic syslog format
loki.process "syslog" {
  stage.regex {
    expression = "^(?P<timestamp>\\\\w+\\\\s+\\\\d+\\\\s+\\\\d+:\\\\d+:\\\\d+)\\\\s+(?P<sys_host>\\\\S+)\\\\s+(?P<program>\\\\S+?)(\\\\[(?P<pid>\\\\d+)\\\\])?:\\\\s+(?P<message>.*)\$"
  }

  stage.labels {
    values = {
      host    = "sys_host",
      program = "program",
    }
  }

  stage.timestamp {
    source   = "timestamp"
    format   = "Jan 2 15:04:05"
    location = "Local"
  }

  forward_to = [loki.write.remote.receiver]
}

// RFC3339 timestamp format (pve-firewall)
loki.process "rfc3339" {
  stage.regex {
    expression = "^(?P<timestamp>\\\\d{4}-\\\\d{2}-\\\\d{2}T\\\\d{2}:\\\\d{2}:\\\\d{2}.\\\\d+[+-]\\\\d{4})\\\\s+(?P<message>.*)\$"
  }

  stage.timestamp {
    source = "timestamp"
    format = "RFC3339Nano"
  }

  forward_to = [loki.write.remote.receiver]
}

// PVE proxy access log format
loki.process "pveproxy" {
  stage.regex {
    expression = "^(?P<remote_addr>\\\\S+)\\\\s+-\\\\s+(?P<user>\\\\S+)\\\\s+\\\\[(?P<timestamp>[^\\\\]]+)\\\\]\\\\s+\\\\"(?P<method>\\\\S+)\\\\s+(?P<path>\\\\S+)\\\\s+(?P<protocol>[^\\"]+)\\\\"\\\\s+(?P<status>\\\\d+)\\\\s+(?P<size>\\\\d+)"
  }

  stage.labels {
    values = {
      user   = "user",
      method = "method",
      status = "status",
    }
  }

  stage.timestamp {
    source = "timestamp"
    format = "02/Jan/2006:15:04:05 -0700"
  }

  forward_to = [loki.write.remote.receiver]
}
EOF

    print_status "alloy configuration created"
}

create_alloy_service() {
    print_status "Creating Alloy systemd service..."

    mkdir -p /var/lib/alloy
    chown root:root /var/lib/alloy

    cat > /etc/systemd/system/alloy.service << 'EOF'
[Unit]
Description=Grafana Alloy (log collector)
Documentation=https://grafana.com/docs/alloy/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/bin/alloy run --server.http.listen-addr=127.0.0.1:12345 --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable alloy
    systemctl start alloy

    print_status "alloy service started"
}

verify_services() {
    print_status "Verifying services..."
    
    sleep 2
    
    if systemctl is-active --quiet node_exporter; then
        print_status "node_exporter is running on port 9100"
    else
        print_error "node_exporter is not running!"
        systemctl status node_exporter --no-pager
    fi
    
    if systemctl is-active --quiet alloy; then
        print_status "alloy is running and sending logs to Loki"
    else
        print_error "alloy is not running!"
        systemctl status alloy --no-pager
    fi

    echo ""
    echo "========================================"
    echo "  Installation Complete!"
    echo "========================================"
    echo ""
    echo "Services running:"
    echo "  • node_exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
    echo "  • alloy: sending logs to ${LOKI_URL}"
    echo ""
    echo "Verify from monitoring server:"
    echo "  curl http://$(hostname -I | awk '{print $1}'):9100/metrics | head"
    echo ""
    echo "Useful commands:"
    echo "  systemctl status node_exporter"
    echo "  systemctl status alloy"
    echo "  journalctl -u node_exporter -f"
    echo "  journalctl -u alloy -f"
    echo ""
}

main() {
    print_header
    check_root
    check_dependencies
    create_user
    install_node_exporter
    create_node_exporter_service
    install_alloy
    create_alloy_config
    create_alloy_service
    verify_services
}

main "$@"
