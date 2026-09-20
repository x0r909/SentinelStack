#!/bin/bash
# SentinelStack Agent - Uninstall Script for Proxmox Host
# Removes node_exporter and alloy systemd services

set -e

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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        exit 1
    fi
}

stop_services() {
    print_status "Stopping services..."
    
    if systemctl is-active --quiet node_exporter; then
        systemctl stop node_exporter
        print_status "node_exporter stopped"
    else
        print_warning "node_exporter is not running"
    fi
    
    if systemctl is-active --quiet alloy; then
        systemctl stop alloy
        print_status "alloy stopped"
    else
        print_warning "alloy is not running"
    fi
}

disable_services() {
    print_status "Disabling services..."
    
    if systemctl is-enabled --quiet node_exporter 2>/dev/null; then
        systemctl disable node_exporter
        print_status "node_exporter disabled"
    fi
    
    if systemctl is-enabled --quiet alloy 2>/dev/null; then
        systemctl disable alloy
        print_status "alloy disabled"
    fi
}

remove_service_files() {
    print_status "Removing systemd service files..."
    
    if [ -f /etc/systemd/system/node_exporter.service ]; then
        rm -f /etc/systemd/system/node_exporter.service
        print_status "Removed node_exporter.service"
    fi
    
    if [ -f /etc/systemd/system/alloy.service ]; then
        rm -f /etc/systemd/system/alloy.service
        print_status "Removed alloy.service"
    fi
    
    systemctl daemon-reload
}

remove_binaries() {
    print_status "Removing binaries..."
    
    if [ -f /usr/local/bin/node_exporter ]; then
        rm -f /usr/local/bin/node_exporter
        print_status "Removed /usr/local/bin/node_exporter"
    fi
    
    if [ -f /usr/local/bin/alloy ]; then
        rm -f /usr/local/bin/alloy
        print_status "Removed /usr/local/bin/alloy"
    fi
}

remove_configs() {
    print_status "Removing configuration files..."
    
    if [ -d /etc/alloy ]; then
        rm -rf /etc/alloy
        print_status "Removed /etc/alloy"
    fi
    
    if [ -d /var/lib/alloy ]; then
        rm -rf /var/lib/alloy
        print_status "Removed /var/lib/alloy"
    fi
}

remove_user() {
    print_status "Removing user..."
    
    if id "node_exporter" &>/dev/null; then
        userdel node_exporter
        print_status "Removed user 'node_exporter'"
    fi
}

show_summary() {
    echo ""
    echo "========================================"
    echo "  Uninstall Complete!"
    echo "========================================"
    echo ""
    echo "Removed:"
    echo "  • node_exporter binary and service"
    echo "  • alloy binary and service"
    echo "  • Configuration files"
    echo "  • User 'node_exporter'"
    echo ""
    echo "To reinstall, run:"
    echo "  ./install.sh"
    echo ""
}

main() {
    echo ""
    echo "========================================"
    echo "  SentinelStack Agent Uninstaller"
    echo "========================================"
    echo ""
    
    read -p "Are you sure you want to uninstall? [y/N] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    check_root
    stop_services
    disable_services
    remove_service_files
    remove_binaries
    remove_configs
    remove_user
    show_summary
}

main "$@"
