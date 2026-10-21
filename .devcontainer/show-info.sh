#!/bin/sh
# ==============================================================================
# Mey2Ray Information Banner & Status Display
# Read-only script: safe to execute on terminal attachment or repeated calls.
# ==============================================================================
set -eu

DATA_FILE="/var/www/dashboard/data.json"
PID_FILE="/var/run/mey2ray/mey2ray.pid"
SUB_FILE="/var/www/sub/index.txt"

echo ""
echo "===================================================================="
echo "                   Mey2Ray - VLESS Proxy System"
echo "===================================================================="

# Check service status
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
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
echo "  [1] Live Subscription (Recommended for auto-updating):"
echo "      Import the Subscription URL into your client (v2rayN, NekoBox,"
echo "      Streisand, Shadowrocket) and update subscription."
echo ""
echo "  [2] Web Dashboard (Local QR code & direct controls):"
echo "      Open the Dashboard URL in your browser to scan the QR code"
echo "      or copy links directly."
echo ""
echo "  [3] Offline Base64 Subscription Payload (One-click import):"
echo "------------------- BEGIN MEY2RAY SUBSCRIPTION -------------------"
if [ -f "$SUB_FILE" ]; then
    cat "$SUB_FILE"
    echo ""
else
    echo "(Subscription file pending generation)"
fi
echo "-------------------- END MEY2RAY SUBSCRIPTION --------------------"
echo ""
echo "Important Notes:"
echo " - Ensure Codespaces port 443 visibility is set to 'Public'."
echo " - Free tier includes 60 hours runtime/month on 2-core machines."
echo "===================================================================="
echo ""
