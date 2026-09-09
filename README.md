# Mey2Ray - VLESS Proxy on GitHub Codespaces

A lightweight VLESS proxy server configured to run inside GitHub Codespaces without requiring local installation or a dedicated VPS.

---

## What You Get

A working VLESS proxy link compatible with standard clients, including v2rayN, NekoBox, Shadowrocket, and Streisand. The proxy runs inside a GitHub-hosted Codespace container, so nothing needs to be installed or hosted on your local machine.

---

## Step-by-Step Setup (For Beginners)

### 1. Fork this repository

1. Go to [github.com/meytiii/mey2ray](https://github.com/meytiii/mey2ray).
2. Click the **Fork** button in the upper-right corner.
3. Click **Create fork** to add a copy under your account.

> Codespaces run from your repository copy, giving you an isolated container instance.

### 2. Create a Codespace

1. In your forked repository (`your-username/mey2ray`), click the green **Code** button.
2. Select the **Codespaces** tab.
3. Click **Create codespace on main**.

A browser tab will open with the web environment. Wait 1 to 2 minutes while GitHub builds the container and executes the startup scripts.

### 3. Retrieve the VLESS links

Once initialization finishes, the integrated terminal displays your generated proxy configuration strings:

```text
========================================
  MeyRay - VLESS Proxy (OLD IPs)
========================================

VLESS links:
vless://4b616b6f-6f6c-4e65-7773-xxx@94.130.50.12:443?encryption=none&security=tls&type=ws&sni=...
```

Copy any of the generated `vless://` links.

### 4. Connect with your client

Paste the copied link into your preferred proxy client (such as v2rayN, NekoBox, Streisand, or Shadowrocket).

> Note: If the Codespace stops and restarts, a new link and UUID are generated automatically. Keep your active configuration saved or restart the container when needed.

---

## Keep Your Proxy Alive Longer

By default, GitHub Codespaces shuts down inactive instances after 30 minutes. You can increase this threshold to the maximum allowable 4 hours (240 minutes):

1. Go to your GitHub account **Settings** (click your profile avatar in the upper right, then select **Settings**).
2. In the left navigation, select **Codespaces**.
3. Under **Default idle timeout**, change the value from `30` to `240` minutes.

Your proxy container will now remain active for up to 4 hours between interactions.

---

## Free Tier Usage Limits (Important)

Personal GitHub accounts include free Codespaces allocations each month:

- **120 core-hours per month** on standard 2-core machines.
- Because this devcontainer uses a 2-core machine, this equals roughly **60 hours of active runtime per month** (120 ÷ 2 = 60).

For example, running the proxy 2 hours a day consumes about 60 hours over a month, reaching the free limit.

Once you exhaust your monthly hours, GitHub pauses Codespaces until the next billing cycle resets. You can track your balance under **Settings > Billing and plans > Plans and usage**.

To conserve hours, stop the Codespace when not in use: open the menu in the upper-left corner of the web editor and select **Stop Current Codespace**.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| No `vless://` links appear in the terminal | Wait 1 to 2 minutes for container initialization to finish. If output is still missing, rebuild or recreate the Codespace. |
| Client fails to connect | Ensure your client supports VLESS with WebSocket transport and TLS. You can also try another IP address from the terminal output list. |
| Codespace will not start | You may have reached your 60-hour monthly limit. Check your GitHub billing settings for quota status. |

---

## Frequently Asked Questions

**Do I need to pay anything?**  
No. GitHub includes 120 core-hours per month on the free tier. Keep your runtime within the 60-hour monthly limit mentioned above.

**Can I run this on my own computer or server?**  
Yes. While this repository is set up for GitHub Codespaces, you can build and run the container locally or on a VPS. See [For Advanced Users (Manual Setup)](#for-advanced-users-manual-setup) below.

**Could GitHub restrict my account?**  
This project is intended for educational and testing purposes. Running proxy services on cloud development environments may conflict with provider acceptable use policies. Use responsibly and at your own discretion.

**Why did the link stop working after a few hours?**  
The Codespace likely timed out due to inactivity, or you reached your monthly core-hour limit. Restarting the Codespace will generate a new connection link and UUID.

---

## For Advanced Users (Manual Setup)

To build and run this container on your own VPS or local Docker host:

```bash
git clone https://github.com/meytiii/mey2ray
cd mey2ray
docker build -t mey2ray .devcontainer
docker run -d -p 443:443 -e VLESS_UUID="your-uuid-here" --name mey2ray mey2ray
```

View the generated connection links from the container logs:

```bash
docker logs mey2ray
```

---

## Disclaimer

This software is provided for educational and research purposes only. The author is not responsible for misuse, excessive bandwidth consumption, or violations of GitHub's Terms of Service. Use at your own risk.
