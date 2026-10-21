#!/bin/sh
set -eu

XRAY_DIR="/usr/local/bin"
FALLBACK_VERSION="v26.3.27"
MAX_RETRIES=3

detect_arch() {
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            echo "64"
            ;;
        aarch64|arm64)
            echo "arm64-v8a"
            ;;
        armv7*|armhf)
            echo "arm32-v7a"
            ;;
        *)
            echo "ERROR: Unsupported architecture: $arch" >&2
            exit 1
            ;;
    esac
}

fetch_latest_version() {
    if [ -n "${XRAY_VERSION:-}" ]; then
        echo "$XRAY_VERSION"
        return 0
    fi

    attempt=1
    version=""
    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        version=$(curl -fsSL --connect-timeout 5 --max-time 10 \
            -H "User-Agent: Mey2Ray-Installer" \
            "https://api.github.com/repos/XTLS/Xray-core/releases/latest" 2>/dev/null \
            | grep '"tag_name"' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)
        
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    echo "WARNING: Failed to query GitHub API. Using fallback version: $FALLBACK_VERSION" >&2
    echo "$FALLBACK_VERSION"
}

ARCH="$(detect_arch)"
VERSION="$(fetch_latest_version)"
URL="https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip"

echo "==> Target Architecture: linux-${ARCH}"
echo "==> Xray-core Version:   ${VERSION}"
echo "==> Download URL:        ${URL}"

TMP_DIR="$(mktemp -d /tmp/xray-install.XXXXXX)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

ZIP_FILE="$TMP_DIR/xray.zip"

echo "==> Downloading Xray release package..."
download_success=0
for i in $(seq 1 "$MAX_RETRIES"); do
    if curl -fsSL --connect-timeout 10 --max-time 120 -o "$ZIP_FILE" "$URL"; then
        download_success=1
        break
    fi
    echo "Download attempt $i failed. Retrying..." >&2
    sleep 3
done

if [ "$download_success" -ne 1 ] || [ ! -s "$ZIP_FILE" ]; then
    echo "ERROR: Failed to download Xray package from $URL" >&2
    exit 1
fi

echo "==> Validating archive integrity..."
if ! unzip -tq "$ZIP_FILE" >/dev/null 2>&1; then
    echo "ERROR: Corrupted zip file downloaded from $URL" >&2
    exit 1
fi

echo "==> Extracting Xray binary..."
unzip -o -q "$ZIP_FILE" xray -d "$TMP_DIR"
if [ ! -f "$TMP_DIR/xray" ]; then
    echo "ERROR: xray binary not found in archive." >&2
    exit 1
fi

chmod +x "$TMP_DIR/xray"
mkdir -p "$XRAY_DIR"
mv "$TMP_DIR/xray" "$XRAY_DIR/xray"

echo "==> Verifying installed binary..."
if ! "$XRAY_DIR/xray" version >/dev/null 2>&1; then
    echo "WARNING: Xray binary installed but 'xray version' returned non-zero." >&2
else
    echo "==> Verification successful: $("$XRAY_DIR/xray" version | head -n 1)"
fi

echo "==> Xray ${VERSION} installed successfully."