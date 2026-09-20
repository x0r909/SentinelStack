#!/bin/bash
# SentinelStack - Config Renderer
# Renders config templates with secrets from .env (secrets never touch git)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$ROOT_DIR/.env" ]; then
    echo "ERROR: .env not found. Run: cp .env.example .env && nano .env"
    exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

render() {
    local src="$1" dst="$2"
    if [ ! -f "$src" ]; then
        echo "ERROR: template not found: $src"
        exit 1
    fi
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [[ "${TELEGRAM_BOT_TOKEN:-}" == YOUR_* ]]; then
        echo "ERROR: TELEGRAM_BOT_TOKEN not set in .env (get token from @BotFather)"
        exit 1
    fi
    if [ -z "${TELEGRAM_CHAT_ID:-}" ] || [[ "${TELEGRAM_CHAT_ID:-}" == YOUR_* ]]; then
        echo "ERROR: TELEGRAM_CHAT_ID not set in .env (get chat id from @userinfobot)"
        exit 1
    fi
    if ! command -v envsubst &>/dev/null; then
        echo "ERROR: envsubst not found (install gettext: apt install gettext)"
        exit 1
    fi
    envsubst < "$src" > "$dst"
    echo "  ✓ rendered $(basename "$dst")"
}

echo "Rendering configs from templates..."
mkdir -p "$ROOT_DIR/alertmanager"
render "$ROOT_DIR/alertmanager/alertmanager.yml.tmpl" "$ROOT_DIR/alertmanager/alertmanager.yml"
echo "Done. Secrets injected from .env (rendered files are gitignored)."
