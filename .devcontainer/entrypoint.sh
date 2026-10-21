#!/bin/sh
set -eu

PID_DIR="/var/run/mey2ray"
PID_FILE="${PID_DIR}/mey2ray.pid"
CONFIG_TEMPLATE="/etc/mey2ray/config.template.json"
CONFIG="/etc/mey2ray/config.json"
NGINX_CONF="/etc/nginx/nginx.conf"
SUB_DIR="/var/www/sub"
DASHBOARD_DIR="/var/www/dashboard"

mkdir -p "$PID_DIR" "$SUB_DIR" "$DASHBOARD_DIR" /etc/mey2ray /var/log/nginx

if [ -f "$PID_FILE" ]; then
    OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "==> Mey2Ray daemon is already active (PID: $OLD_PID)."
        if [ -x "/usr/local/bin/show-info.sh" ]; then
            exec /usr/local/bin/show-info.sh
        fi
        exit 0
    fi
fi

echo "$$" > "$PID_FILE"

XRAY_PID=""
NGINX_PID=""

cleanup() {
    echo ""
    echo "==> Mey2Ray received termination signal. Stopping services..."
    if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
        kill -QUIT "$NGINX_PID" 2>/dev/null || true
    fi
    if [ -n "$XRAY_PID" ] && kill -0 "$XRAY_PID" 2>/dev/null; then
        kill -TERM "$XRAY_PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    echo "==> Shutdown complete."
    exit 0
}

trap cleanup INT TERM HUP QUIT

validate_uuid() {
    val="$1"
    case "$val" in
        [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

generate_random_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        hex="$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')"
        p1=$(echo "$hex" | cut -c 1-8)
        p2=$(echo "$hex" | cut -c 9-12)
        p3="4$(echo "$hex" | cut -c 14-16)"
        c=$(echo "$hex" | cut -c 17)
        case "$c" in
            [0-3]) v="8" ;;
            [4-7]) v="9" ;;
            [8-9a-b]) v="a" ;;
            *) v="b" ;;
        esac
        p4="${v}$(echo "$hex" | cut -c 18-20)"
        p5=$(echo "$hex" | cut -c 21-32)
        echo "${p1}-${p2}-${p3}-${p4}-${p5}"
    fi
}

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
mkdir -p "$STATE_DIR"
UUID_STORAGE_FILE="${STATE_DIR}/uuid"

UUID=""
if [ -n "${VLESS_UUID:-}" ]; then
    if validate_uuid "$VLESS_UUID"; then
        UUID="$VLESS_UUID"
        echo "==> Using explicitly provided VLESS_UUID."
    else
        echo "FATAL: Configured VLESS_UUID ('$VLESS_UUID') is not a valid RFC 4122 UUID." >&2
        exit 1
    fi
    TMP_UUID_FILE="${UUID_STORAGE_FILE}.tmp.$$"
    echo "$UUID" > "$TMP_UUID_FILE"
    chmod 600 "$TMP_UUID_FILE"
    mv "$TMP_UUID_FILE" "$UUID_STORAGE_FILE"
else
    if [ -f "$UUID_STORAGE_FILE" ]; then
        EXISTING_UUID="$(head -n 1 "$UUID_STORAGE_FILE" | tr -d ' \r\n')"
        if validate_uuid "$EXISTING_UUID"; then
            UUID="$EXISTING_UUID"
            echo "==> Loaded persistent UUID from storage."
        fi
    fi

    if [ -z "$UUID" ]; then
        UUID="$(generate_random_uuid)"
        if ! validate_uuid "$UUID"; then
            echo "FATAL: Failed to generate valid UUID." >&2
            exit 1
        fi
        TMP_UUID_FILE="${UUID_STORAGE_FILE}.tmp.$$"
        echo "$UUID" > "$TMP_UUID_FILE"
        chmod 600 "$TMP_UUID_FILE"
        mv "$TMP_UUID_FILE" "$UUID_STORAGE_FILE"
        echo "==> Generated and saved new persistent UUID."
    fi
fi

IPS_FILE=""
for candidate in /etc/mey2ray/ips.txt .devcontainer/ips.txt ./ips.txt /app/ips.txt; do
    if [ -f "$candidate" ]; then
        IPS_FILE="$candidate"
        break
    fi
done

if [ -z "$IPS_FILE" ]; then
    echo "FATAL: Server IP configuration file (ips.txt) not found." >&2
    exit 1
fi

validate_ipv4() {
    ip_candidate="$1"
    old_ifs="$IFS"
    IFS='.'
    set -- $ip_candidate
    IFS="$old_ifs"
    if [ "$#" -ne 4 ]; then
        return 1
    fi
    for octet in "$@"; do
        case "$octet" in
            ''|*[!0-9]*) return 1 ;;
        esac
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            return 1
        fi
    done
    return 0
}

VALID_IPS=""
SEEN_IPS=""

while IFS= read -r line || [ -n "$line" ]; do
    clean_line="$(echo "$line" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    
    case "$clean_line" in
        ''|\#*) continue ;;
    esac

    ip_entry="$(echo "$clean_line" | awk '{print $1}')"

    if validate_ipv4 "$ip_entry"; then
        case " $SEEN_IPS " in
            *" $ip_entry "*)
                ;;
            *)
                SEEN_IPS="$SEEN_IPS $ip_entry"
                if [ -z "$VALID_IPS" ]; then
                    VALID_IPS="$ip_entry"
                else
                    VALID_IPS="$VALID_IPS
$ip_entry"
                fi
                ;;
        esac
    else
        echo "WARNING: Skipping invalid IP entry in ips.txt: '$ip_entry'" >&2
    fi
done < "$IPS_FILE"

if [ -z "$VALID_IPS" ]; then
    echo "WARNING: No valid IPs parsed from $IPS_FILE. Falling back to 127.0.0.1" >&2
    VALID_IPS="127.0.0.1"
fi

if [ -n "${CODESPACE_NAME:-}" ]; then
    DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    SNI="${CODESPACE_NAME}-443.${DOMAIN}"
elif [ -n "${PUBLIC_HOST:-}" ]; then
    SNI="$PUBLIC_HOST"
else
    SNI="localhost"
fi

if [ "$SNI" = "localhost" ]; then
    SUB_URL="http://localhost:443/sub"
else
    SUB_URL="https://${SNI}/sub"
fi

RAW_LINKS=""
LINKS_JSON="["
COUNT=0

OLD_IFS="$IFS"
IFS='
'
for ip in $VALID_IPS; do
    COUNT=$((COUNT + 1))
    PADDED_INDEX="$(printf "%02d" "$COUNT")"
    REMARK="Mey2Ray-${PADDED_INDEX}%20%28${ip}%29"
    
    LINK="vless://${UUID}@${ip}:443?encryption=none&security=tls&type=ws&host=${SNI}&sni=${SNI}&path=%2F&alpn=http%2F1.1&fp=chrome#${REMARK}"
    
    if [ -z "$RAW_LINKS" ]; then
        RAW_LINKS="$LINK"
        LINKS_JSON="${LINKS_JSON}\"${LINK}\""
    else
        RAW_LINKS="$RAW_LINKS
$LINK"
        LINKS_JSON="${LINKS_JSON},\"${LINK}\""
    fi
done
IFS="$OLD_IFS"
LINKS_JSON="${LINKS_JSON}]"

echo "$RAW_LINKS" > "${SUB_DIR}/links.txt"

OFFLINE_B64="$(printf "%s\n" "$RAW_LINKS" | base64 | tr -d '\r\n')"
echo "$OFFLINE_B64" > "${SUB_DIR}/index.txt"
chmod 644 "${SUB_DIR}/index.txt"

cat <<EOF > "${DASHBOARD_DIR}/data.json"
{
  "subscriptionUrl": "${SUB_URL}",
  "profileCount": ${COUNT},
  "links": ${LINKS_JSON},
  "offlineBase64": "${OFFLINE_B64}"
}
EOF
chmod 644 "${DASHBOARD_DIR}/data.json"

if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "FATAL: Xray configuration template ($CONFIG_TEMPLATE) missing." >&2
    exit 1
fi

sed "s/\${UUID}/$UUID/g" "$CONFIG_TEMPLATE" > "$CONFIG"
chmod 600 "$CONFIG"

echo "==> Testing Xray configuration..."
if ! /usr/local/bin/xray -test -c "$CONFIG" >/dev/null 2>&1; then
    echo "FATAL: Xray configuration test failed." >&2
    /usr/local/bin/xray -test -c "$CONFIG"
    exit 1
fi

echo "==> Starting Xray engine (127.0.0.1:8443)..."
/usr/local/bin/xray -c "$CONFIG" >/var/log/xray.log 2>&1 &
XRAY_PID=$!

ready=0
for i in $(seq 1 10); do
    if ! kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "FATAL: Xray process exited unexpectedly during startup. Inspecting log:" >&2
        cat /var/log/xray.log >&2
        exit 1
    fi
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1 http://127.0.0.1:8443/ >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done

echo "==> Xray engine initialized successfully."

echo "==> Testing Nginx configuration..."
if ! nginx -t -c "$NGINX_CONF" >/dev/null 2>&1; then
    echo "FATAL: Nginx configuration test failed." >&2
    nginx -t -c "$NGINX_CONF"
    exit 1
fi

echo "==> Starting Nginx reverse proxy (Port 443)..."
nginx -c "$NGINX_CONF" &
NGINX_PID=$!

nginx_ready=0
for i in $(seq 1 10); do
    if [ "$(curl -fsSL --connect-timeout 1 http://127.0.0.1:443/healthz 2>/dev/null || true)" = "OK" ]; then
        nginx_ready=1
        break
    fi
    sleep 1
done

if [ "$nginx_ready" -ne 1 ]; then
    echo "FATAL: Nginx reverse proxy failed to respond on http://127.0.0.1:443/healthz" >&2
    exit 1
fi

echo "==> Nginx reverse proxy initialized successfully."

if [ -x "/usr/local/bin/show-info.sh" ]; then
    /usr/local/bin/show-info.sh
fi

echo "==> Mey2Ray daemon active. Supervising services..."

while true; do
    if ! kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "ERROR: Xray process (PID $XRAY_PID) terminated." >&2
        cleanup
    fi
    if ! kill -0 "$NGINX_PID" 2>/dev/null; then
        echo "ERROR: Nginx process (PID $NGINX_PID) terminated." >&2
        cleanup
    fi
    sleep 5
done
