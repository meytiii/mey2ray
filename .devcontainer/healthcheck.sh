#!/bin/sh
set -eu

NGINX_STATUS=$(curl -fsSL --connect-timeout 2 --max-time 3 http://127.0.0.1:443/healthz 2>/dev/null || true)
if [ "$NGINX_STATUS" != "OK" ]; then
    echo "HEALTHCHECK FAILED: Nginx on port 443 did not return expected healthz response." >&2
    exit 1
fi

if ! pgrep -x xray >/dev/null 2>&1; then
    echo "HEALTHCHECK FAILED: Xray process is not running." >&2
    exit 1
fi

XRAY_PROBE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 3 http://127.0.0.1:8443/ || true)
if [ -z "$XRAY_PROBE" ] || [ "$XRAY_PROBE" = "000" ]; then
    echo "HEALTHCHECK FAILED: Cannot connect to Xray on 127.0.0.1:8443." >&2
    exit 1
fi

exit 0
