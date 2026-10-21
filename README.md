# Mey2Ray — Resilient VLESS Proxy Infrastructure

[English](README.md) | [فارسی](README.fa.md)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/meytiii/mey2ray?quickstart=1)

A hardened, lightweight VLESS proxy engine built on [Xray-core](https://github.com/XTLS/Xray-core) and an Nginx reverse proxy. Configured to run inside **GitHub Codespaces** or any Docker/VPS host with zero local software requirements.

Featuring persistent UUID management, a clean IP configuration system, a live auto-updating subscription endpoint, an offline Base64 subscription block, and a responsive web dashboard with client-side QR code generation.

---

## Key Features

- **Direct Codespace Domain Profile:** Primary profile (`Mey2Ray-01`) routing through your unique Codespace edge domain alongside 23 validated external IP endpoints (24 total endpoints).
- **Integrated Nginx Reverse Proxy:** Efficiently routes incoming traffic — WebSocket connections proxy to Xray-core on `127.0.0.1:8443`, web requests serve the dashboard, and `/sub` delivers Base64 subscription payloads.
- **Persistent UUID Identity:** Your client credentials survive Codespaces stops, restarts, and terminal sessions. Optionally override with an explicit `VLESS_UUID` environment variable.
- **Live Auto-Updating Subscription (`/sub`):** Import a single URL into your proxy client; updates automatically sync all active server endpoints with zero manual link copying.
- **Offline Base64 Subscription:** Copy a single Base64 block to instantly import all profiles without relying on a live HTTP connection to Codespaces.
- **Minimalist Web Dashboard:** Dark-themed web interface (`#0B101E`) with one-click copy buttons and a 100% offline, client-side QR code generator (zero third-party API tracking).
- **Persistent Keepalive System:** Multi-vector background edge pulse keeping your Codespace alive for the full session allocation.
- **Externalized IP Management (`ips.txt`):** Easily add, test, or organize server endpoints in a clean configuration file with automatic duplicate filtering and IPv4 validation.
- **Deterministic Lifecycle:** Eliminates duplicate process spawning and config corruption upon terminal re-attachment. Includes an accurate multi-service healthcheck.

---

## Architecture Overview

```text
[ Client (v2rayN / NekoBox / Shadowrocket) ]
                       │
                       │ TLS Handshake (SNI: <codespace>-443.app.github.dev)
                       ▼
         [ GitHub Codespaces Edge Proxy ]
                       │ (Terminates TLS, forwards cleartext HTTP to port 443)
                       ▼
              [ In-Container Nginx (Port 443) ]
                       │
       ┌───────────────┼───────────────┬─────────────────────────┐
       ▼               ▼               ▼                         ▼
   GET /           GET /sub        GET /healthz           WebSocket (Upgrade: ws)
[ Web Dashboard ] [ Base64 Sub ] [ Health Probe ]                │
                                                                 ▼
                                                  [ Xray-core (127.0.0.1:8443) ]
                                                  ├── Direct Routing (Freedom)
                                                  └── BitTorrent (Blackhole Dropped)
```

---

## Quickstart Guide

### 1. Recommended Settings (Before Launch)
For minimal latency and uninterrupted service, configure these settings in your GitHub account:
1. Open **[GitHub Codespaces Settings](https://github.com/settings/codespaces)**.
2. Set **Region** to **`Europe West`** (best ping and lowest packet loss).
3. Set **Default idle timeout** to the maximum **`240`** minutes.

### 2. One-Click Launch
Click the button below to fork and launch a dedicated Codespace instance:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/meytiii/mey2ray?quickstart=1)

*Or manually:*
1. Fork this repository to your GitHub account.
2. In your fork, click **Code** > **Codespaces** > **Create codespace on main**.
3. Wait 1–2 minutes while GitHub builds the container environment.

### 3. Retrieve Your Proxy Credentials
Once initialization completes, the integrated terminal displays your service URLs and subscription payload:

```text
====================================================================
                   Mey2Ray - VLESS Proxy System
====================================================================
  Status:           [ RUNNING ] (Supervising Xray + Nginx)
  Dashboard URL:    https://<codespace-name>-443.app.github.dev/
  Subscription URL: https://<codespace-name>-443.app.github.dev/sub
  Active Endpoints: 24 validated servers
====================================================================
```

### 4. Connect With Your Preferred Client

#### Method A: Live Subscription URL (Recommended)
1. Copy the **Subscription URL** (`https://<codespace-name>-443.app.github.dev/sub`).
2. In your proxy client (**v2rayN**, **v2rayNG**, **NekoBox**, **Streisand**, or **Shadowrocket**):
   - Add a new **Subscription Group**.
   - Paste the Subscription URL and save.
   - Click **Update Subscription**.
3. All 24 configured endpoints will populate automatically.

#### Method B: Web Dashboard & QR Code
1. Open the **Dashboard URL** in your web browser.
2. Scan the on-screen QR code using your mobile proxy client.
3. Or click **Copy Subscription URL** / **Copy All Links**.

#### Method C: Offline Base64 Payload
If the Codespace is temporarily stopped or network access to GitHub is restricted:
1. Copy the entire Base64 payload block between `BEGIN MEY2RAY SUBSCRIPTION` and `END MEY2RAY SUBSCRIPTION`.
2. In your client app, choose **Import from Clipboard**.

---

## Configuration & Customization

### Adding or Modifying Server IPs (`.devcontainer/ips.txt`)
Edit `.devcontainer/ips.txt` to manage your routing endpoints:
- Supports `#` comments and blank lines.
- Automatic deduplication and IPv4 validation.
- Changes take effect upon container restart.

```text
# [Custom Fronting Endpoints]
192.0.2.1
198.51.100.24
```

### Persistent UUID & Custom Credentials
- By default, a valid UUID is generated on first startup and persisted in `.devcontainer/.state/uuid`. It survives Codespace stops, starts, and terminal disconnects.
- To use a specific UUID across rebuilds, set the `VLESS_UUID` Codespace Secret or environment variable:
  ```bash
  export VLESS_UUID="b8214156-f947-4952-b91c-7f5518b0e8b2"
  ```

### Extending Codespace Uptime
By default, GitHub shuts down idle Codespaces after 30 minutes. To increase uptime to the maximum 4 hours (240 minutes):
1. Go to **GitHub Settings** > **Codespaces**.
2. Under **Default idle timeout**, change `30` to `240` minutes.

---

## Free Tier Usage & Quotas

GitHub personal accounts include free monthly Codespaces allocations:
- **120 core-hours per month** on standard 2-core machines = **~60 hours of active monthly runtime**.
- Check remaining hours in **GitHub Settings** > **Billing and plans** > **Plans and usage**.
- Conserve quota by stopping the container when not in use: **Menu (top left)** > **Stop Current Codespace**.

---

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| **Subscription URL returns 404 or fails to load** | Codespaces port visibility is set to Private. | Open the **Ports** tab in Codespaces, right-click Port `443`, and select **Port Visibility > Public**. |
| **Dashboard loads, but client cannot connect** | ISP/firewall blocks direct connection to the target server IP. | Switch to another IP from the list or update `.devcontainer/ips.txt` with clean, accessible addresses. |
| **Terminal output closed or cleared** | Session re-attached. | Run `/usr/local/bin/show-info.sh` in the terminal to re-display URLs, status, and subscription blocks without restarting services. |
| **Container fails healthcheck** | Nginx or Xray failed to bind ports or configuration error. | Run `sudo nginx -t` and inspect `/var/log/xray.log` or `/var/log/nginx/error.log`. |
| **Docker build failed (GitHub API rate limit)** | Unauthenticated release query exceeded rate limits. | The installer automatically switches to a verified stable fallback release (`v26.3.27`). Re-trigger build. |

---

## Advanced: Manual Docker & VPS Deployment

To run this hardened stack on your own Linux VPS or local Docker host:

```bash
git clone https://github.com/meytiii/mey2ray.git
cd mey2ray

# Build container
docker build -t mey2ray .devcontainer

# Run with persistent volume and custom domain
docker run -d \
  -p 443:443 \
  -e PUBLIC_HOST="your-domain.com" \
  -e VLESS_UUID="your-custom-uuid-here" \
  -v $(pwd)/.devcontainer/.state:/devcontainer/.state \
  --name mey2ray \
  --restart unless-stopped \
  mey2ray

# Inspect runtime credentials and subscription
docker exec mey2ray /usr/local/bin/show-info.sh
```

---

## Disclaimer & Terms of Service

This repository is provided strictly for educational, security auditing, and network research purposes. Users are responsible for complying with GitHub's Terms of Service and Acceptable Use Policies. The maintainers assume no liability for misuse, bandwidth consumption, or account penalties.
