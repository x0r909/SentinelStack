#!/bin/bash
# SentinelStack - Backup Script
# Backs up configs + snapshots all data volumes
# Usage:
#   ./scripts/backup.sh [BACKUP_DIR]
# Cron example (daily 02:00):
#   0 2 * * * /opt/sentinel-stack/scripts/backup.sh /backup >> /var/log/sentinel-backup.log 2>&1
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${1:-$ROOT_DIR/backups}"
RETENTION_DAYS=7
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "  SentinelStack Backup - $STAMP"
echo "=========================================="
echo "Destination: $BACKUP_DIR"

# ============================================
# 1. Config backup (small, always safe)
# ============================================
echo ""
echo "[1/3] Backing up configs..."
tar -czf "$BACKUP_DIR/sentinel-config-$STAMP.tar.gz" \
    -C "$ROOT_DIR" \
    docker-compose.yml .env.example \
    prometheus/ alertmanager/ loki/ alloy/ tempo/ blackbox/ caddy/ grafana/ scripts/ agents/ 2>/dev/null \
    || tar -czf "$BACKUP_DIR/sentinel-config-$STAMP.tar.gz" -C "$ROOT_DIR" \
        docker-compose.yml prometheus/ alertmanager/ loki/ alloy/ tempo/ blackbox/ caddy/ grafana/ scripts/ agents/
echo "  ✓ sentinel-config-$STAMP.tar.gz"

# ============================================
# 2. Data volume snapshots (requires running Docker)
# ============================================
if command -v docker &>/dev/null && docker info &>/dev/null; then
    echo ""
    echo "[2/3] Snapshotting data volumes..."

    snapshot_volume() {
        local vol="$1" out="$2"
        if docker volume inspect "$vol" &>/dev/null; then
            echo "  → $vol ..."
            docker run --rm \
                -v "$vol":/source:ro \
                -v "$WORK_DIR":/backup \
                alpine tar -czf "/backup/$out" -C /source .
            mv "$WORK_DIR/$out" "$BACKUP_DIR/$out"
            echo "    ✓ $out"
        else
            echo "    ⚠ volume $vol not found, skipped"
        fi
    }

    snapshot_volume "sentinel-prometheus-data"  "sentinel-prometheus-$STAMP.tar.gz"
    snapshot_volume "sentinel-loki-data"        "sentinel-loki-$STAMP.tar.gz"
    snapshot_volume "sentinel-grafana-data"     "sentinel-grafana-$STAMP.tar.gz"
    snapshot_volume "sentinel-uptime-kuma-data" "sentinel-uptime-kuma-$STAMP.tar.gz"
else
    echo ""
    echo "[2/3] Docker not available — data volume snapshot skipped (config only)"
fi

# ============================================
# 3. Retention: keep last N days
# ============================================
echo ""
echo "[3/3] Applying retention (${RETENTION_DAYS} days)..."
find "$BACKUP_DIR" -name "sentinel-*.tar.gz" -mtime +${RETENTION_DAYS} -print -delete | while read -r f; do
    echo "  deleted: $(basename "$f")"
done

echo ""
echo "Backup complete."
echo "Files:"
ls -lh "$BACKUP_DIR" | tail -n +2

# ============================================
# Optional: off-site sync
# ============================================
# Uncomment and configure for off-site copy (rsync over SSH):
# REMOTE_HOST="user@backup-server"
# REMOTE_DIR="/backup/sentinel"
# rsync -az --progress "$BACKUP_DIR/" "$REMOTE_HOST:$REMOTE_DIR/"
# echo "✓ Off-site sync to $REMOTE_HOST"
