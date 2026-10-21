#!/bin/sh
set -eu

DATA_FILE="/var/www/dashboard/data.json"
PID_FILE="/var/run/mey2ray/mey2ray.pid"

is_service_running() {
    if [ -f "$PID_FILE" ]; then
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

if ! is_service_running; then
    echo "==> Mey2Ray proxy daemon is not running. Auto-starting services in background..."
    if [ "$(id -u)" -eq 0 ]; then
        nohup /usr/local/bin/entrypoint.sh >/var/log/mey2ray.log 2>&1 &
    else
        sudo nohup /usr/local/bin/entrypoint.sh >/var/log/mey2ray.log 2>&1 &
    fi
    for i in 1 2 3 4 5 6; do
        if is_service_running && [ -f "$DATA_FILE" ]; then
            break
        fi
        sleep 1
    done
fi

echo ""
echo "===================================================================="
echo "                   Mey2Ray - VLESS Proxy System"
echo "===================================================================="

if is_service_running; then
    echo "  Status:           [ RUNNING ] (Supervising Xray + Nginx)"
else
    echo "  Status:           [ INITIALIZING / STOPPED ]"
fi

if [ -f "$DATA_FILE" ]; then
    SUB_URL=$(grep '"subscriptionUrl"' "$DATA_FILE" | sed -E 's/.*"subscriptionUrl": *"([^"]+)".*/\1/' || true)
    PROFILE_COUNT=$(grep '"profileCount"' "$DATA_FILE" | sed -E 's/.*"profileCount": *([0-9]+).*/\1/' || true)
    DASHBOARD_URL=$(echo "$SUB_URL" | sed 's|/sub$|/|')
    
    echo "  Dashboard URL:    $DASHBOARD_URL"
    echo "  Subscription URL: $SUB_URL"
    echo "  Active Endpoints: $PROFILE_COUNT validated servers"
else
    SNI="${CODESPACE_NAME:-localhost}-443.app.github.dev"
    echo "  Dashboard URL:    https://${SNI}/"
    echo "  Subscription URL: https://${SNI}/sub"
fi

echo "===================================================================="
echo ""
