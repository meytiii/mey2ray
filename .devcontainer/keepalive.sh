#!/bin/sh
set -eu

STATE_DIR=""
for candidate in /workspaces/* "$PWD" /app; do
    if [ -d "$candidate" ] && [ -w "$candidate" ]; then
        if [ -d "$candidate/.devcontainer" ] || [ -d "$candidate/.git" ]; then
            STATE_DIR="$candidate/.devcontainer/.state"
            break
        fi
    fi
done

if [ -z "$STATE_DIR" ]; then
    STATE_DIR="/etc/mey2ray"
fi

if [ -n "${CODESPACE_NAME:-}" ]; then
    DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    TARGET_URL="https://${CODESPACE_NAME}-443.${DOMAIN}/healthz"
else
    TARGET_URL="http://127.0.0.1:443/healthz"
fi

while true; do
    curl -fsSL --connect-timeout 4 --max-time 8 "$TARGET_URL" >/dev/null 2>&1 || true
    curl -fsSL --connect-timeout 2 --max-time 4 "http://127.0.0.1:443/healthz" >/dev/null 2>&1 || true
    date +%s > "${STATE_DIR}/heartbeat" 2>/dev/null || true
    sleep 60
done
