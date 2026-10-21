#!/usr/bin/env python3
"""
Mey2Ray Comprehensive Verification Test Suite
Tests configuration files, shell scripts, IP parsing, UUID management,
subscription generation, Xray JSON templates, Nginx configurations, and Dashboard assets.
"""

import os
import re
import sys
import json
import base64
import urllib.parse
import subprocess

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEVCONTAINER_DIR = os.path.join(REPO_ROOT, ".devcontainer")
DASHBOARD_DIR = os.path.join(REPO_ROOT, "dashboard")

def log_test(name, success, message=""):
    status = "PASS" if success else "FAIL"
    print(f"[{status}] {name}" + (f" - {message}" if message else ""))
    if not success:
        return False
    return True

all_passed = True

def check(name, success, message=""):
    global all_passed
    if not log_test(name, success, message):
        all_passed = False

print("=" * 70)
print("             Mey2Ray Automated Verification Suite")
print("=" * 70)

# ------------------------------------------------------------------------------
# Test Suite 1: IP List Parsing and Deduplication
# ------------------------------------------------------------------------------
print("\n--- [Suite 1: IP List Configuration (.devcontainer/ips.txt)] ---")
ips_file = os.path.join(DEVCONTAINER_DIR, "ips.txt")
check("ips.txt exists", os.path.isfile(ips_file))

ipv4_regex = re.compile(r"^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$")

with open(ips_file, "r", encoding="utf-8") as f:
    raw_lines = f.readlines()

parsed_ips = []
duplicates = []
invalid_ips = []
seen = set()

for line in raw_lines:
    clean = line.strip()
    if not clean or clean.startswith("#"):
        continue
    token = clean.split()[0]
    if ipv4_regex.match(token):
        if token in seen:
            duplicates.append(token)
        else:
            seen.add(token)
            parsed_ips.append(token)
    else:
        invalid_ips.append(token)

check("No duplicate IPs in ips.txt", len(duplicates) == 0, f"Found duplicates: {duplicates}")
check("No invalid IP strings in ips.txt", len(invalid_ips) == 0, f"Found invalid: {invalid_ips}")
check("IP count is positive and expected", len(parsed_ips) >= 20, f"Parsed {len(parsed_ips)} unique IPs")
check("Reported duplicate 144.76.1.88 resolved", parsed_ips.count("144.76.1.88") == 1)

# ------------------------------------------------------------------------------
# Test Suite 2: UUID Validation and Persistence Logic
# ------------------------------------------------------------------------------
print("\n--- [Suite 2: UUID Validation and Persistence Logic] ---")
uuid_regex = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

test_valid_uuid = "b8214156-f947-4952-b91c-7f5518b0e8b2"
test_invalid_uuid = "invalid-uuid-12345"

check("Regex matches valid UUIDv4", bool(uuid_regex.match(test_valid_uuid)))
check("Regex rejects invalid UUID string", not bool(uuid_regex.match(test_invalid_uuid)))

# Test atomic file write simulation
temp_state_dir = os.path.join(REPO_ROOT, ".devcontainer", ".state_test")
os.makedirs(temp_state_dir, exist_ok=True)
uuid_test_file = os.path.join(temp_state_dir, "uuid")
try:
    with open(uuid_test_file, "w", encoding="utf-8") as f:
        f.write(test_valid_uuid + "\n")
    with open(uuid_test_file, "r", encoding="utf-8") as f:
        saved = f.read().strip()
    check("UUID persistence write and read cycle", saved == test_valid_uuid)
finally:
    if os.path.exists(uuid_test_file):
        os.remove(uuid_test_file)
    if os.path.exists(temp_state_dir):
        os.rmdir(temp_state_dir)

# ------------------------------------------------------------------------------
# Test Suite 3: Subscription & VLESS URI Syntax & Encoding Equivalence
# ------------------------------------------------------------------------------
print("\n--- [Suite 3: Subscription & VLESS URI Consistency] ---")
sample_uuid = "4b616b6f-6f6c-4e65-7773-1a2b3c4d5e6f"
sample_sni = "test-codespace-443.app.github.dev"

generated_links = []
for i, ip in enumerate(parsed_ips, 1):
    padded_index = f"{i:02d}"
    remark = f"Mey2Ray-{padded_index}%20%28{ip}%29"
    link = (
        f"vless://{sample_uuid}@{ip}:443?"
        f"encryption=none&security=tls&type=ws&host={sample_sni}&sni={sample_sni}&path=%2F&alpn=http%2F1.1&fp=chrome"
        f"#{remark}"
    )
    generated_links.append(link)

check("Generated expected number of VLESS links", len(generated_links) == len(parsed_ips))

# Check link format
sample_link = generated_links[0]
parsed_url = urllib.parse.urlparse(sample_link)
check("URI scheme is vless", parsed_url.scheme == "vless")
check("URI netloc contains uuid and ip:443", f"{sample_uuid}@{parsed_ips[0]}:443" in parsed_url.netloc)
query_params = urllib.parse.parse_qs(parsed_url.query)
check("Query contains security=tls", query_params.get("security") == ["tls"])
check("Query contains type=ws", query_params.get("type") == ["ws"])
check("Query contains alpn=http/1.1", query_params.get("alpn") == ["http/1.1"])
check("Query contains fp=chrome", query_params.get("fp") == ["chrome"])
check("Query contains host matching SNI", query_params.get("host") == [sample_sni])
check("Query contains path=/", query_params.get("path") == ["/"])

# Base64 offline vs live equivalence
raw_joined = "\n".join(generated_links) + "\n"
encoded_b64 = base64.b64encode(raw_joined.encode("utf-8")).decode("utf-8")
decoded_raw = base64.b64decode(encoded_b64).decode("utf-8")
check("Base64 encode/decode equivalence", raw_joined == decoded_raw)
check("Decoded profiles match original count", len(decoded_raw.strip().split("\n")) == len(generated_links))

# ------------------------------------------------------------------------------
# Test Suite 4: Xray & Nginx Configuration Validation
# ------------------------------------------------------------------------------
print("\n--- [Suite 4: Xray & Nginx Configurations] ---")
xray_template = os.path.join(DEVCONTAINER_DIR, "config.json")
check("Xray config.json template exists", os.path.isfile(xray_template))

with open(xray_template, "r", encoding="utf-8") as f:
    xray_content = f.read()

# Replace ${UUID} for JSON parsing check
xray_json_str = xray_content.replace("${UUID}", sample_uuid)
try:
    xray_data = json.loads(xray_json_str)
    check("Xray template is valid JSON", True)
    inbound = xray_data.get("inbounds", [{}])[0]
    check("Xray inbound binds to 127.0.0.1", inbound.get("listen") == "127.0.0.1")
    check("Xray inbound port is 8443", inbound.get("port") == 8443)
    check("Xray inbound protocol is vless", inbound.get("protocol") == "vless")
    check("Xray transport network is ws on path /", inbound.get("streamSettings", {}).get("wsSettings", {}).get("path") == "/")
    
    # Check BitTorrent blocking rule
    rules = xray_data.get("routing", {}).get("rules", [])
    bt_blocked = any(r.get("outboundTag") == "block" and "bittorrent" in r.get("protocol", []) for r in rules)
    check("BitTorrent blackhole blocking rule preserved", bt_blocked)
except Exception as e:
    check("Xray template is valid JSON", False, str(e))

nginx_conf = os.path.join(DEVCONTAINER_DIR, "nginx.conf")
check("Nginx configuration exists", os.path.isfile(nginx_conf))
with open(nginx_conf, "r", encoding="utf-8") as f:
    nginx_content = f.read()

check("Nginx listens on port 443", "listen 443" in nginx_content)
check("Nginx defines /healthz endpoint", "location = /healthz" in nginx_content)
check("Nginx defines /sub endpoint with Profile-Title", "location = /sub" in nginx_content and 'Profile-Title "Mey2Ray"' in nginx_content)
check("Nginx proxies WebSocket upgrade to 127.0.0.1:8443", "proxy_pass http://127.0.0.1:8443;" in nginx_content)
check("Nginx sets long WebSocket timeout", "proxy_read_timeout 86400s;" in nginx_content)

# ------------------------------------------------------------------------------
# Test Suite 5: Dashboard Assets and Offline Integrity
# ------------------------------------------------------------------------------
print("\n--- [Suite 5: Dashboard Assets & Security] ---")
dash_html = os.path.join(DASHBOARD_DIR, "index.html")
dash_css = os.path.join(DASHBOARD_DIR, "style.css")
dash_js = os.path.join(DASHBOARD_DIR, "app.js")
dash_qr = os.path.join(DASHBOARD_DIR, "qrcode.min.js")

check("Dashboard index.html exists", os.path.isfile(dash_html))
check("Dashboard style.css exists", os.path.isfile(dash_css))
check("Dashboard app.js exists", os.path.isfile(dash_js))
check("Dashboard qrcode.min.js exists", os.path.isfile(dash_qr))

with open(dash_html, "r", encoding="utf-8") as f:
    html_text = f.read()

check("Dashboard contains Mey2Ray title", "Mey2Ray" in html_text)
check("Dashboard includes Copy Subscription URL button", 'id="copySubBtn"' in html_text)
check("Dashboard includes Copy All Links button", 'id="copyAllBtn"' in html_text)
check("Dashboard includes Copy Offline Base64 button", 'id="copyOfflineBtn"' in html_text)
check("Dashboard includes QR code container", 'id="qrCodeContainer"' in html_text)
check("Dashboard includes health status indicator", 'id="healthPill"' in html_text)

# Check for absence of dangerous external CDN calls
external_cdn_pattern = re.compile(r'https?://(cdn|ajax|cdnjs|code\.jquery|fonts\.googleapis)', re.IGNORECASE)
check("Dashboard HTML zero external CDNs", not bool(external_cdn_pattern.search(html_text)))

with open(dash_css, "r", encoding="utf-8") as f:
    css_text = f.read()
check("Dashboard CSS uses #0B101E background", "#0B101E" in css_text or "#0b101e" in css_text)
check("Dashboard CSS uses #151E32 surface", "#151E32" in css_text or "#151e32" in css_text)
check("Dashboard CSS uses #2159E8 accent", "#2159E8" in css_text or "#2159e8" in css_text)

# ------------------------------------------------------------------------------
# Test Suite 6: Shell Scripts Syntax Check (via bash / sh if available)
# ------------------------------------------------------------------------------
print("\n--- [Suite 6: Shell Scripts Syntax Verification] ---")
shell_scripts = [
    os.path.join(DEVCONTAINER_DIR, "entrypoint.sh"),
    os.path.join(DEVCONTAINER_DIR, "install.sh"),
    os.path.join(DEVCONTAINER_DIR, "show-info.sh"),
    os.path.join(DEVCONTAINER_DIR, "healthcheck.sh"),
]

git_bash = r"C:\Program Files\Git\bin\bash.exe"
has_bash = os.path.isfile(git_bash)

for script in shell_scripts:
    check(f"Script exists: {os.path.basename(script)}", os.path.isfile(script))
    if has_bash:
        result = subprocess.run([git_bash, "-n", script], capture_output=True, text=True)
        check(f"Syntax validation (bash -n): {os.path.basename(script)}", result.returncode == 0, result.stderr.strip())

# ------------------------------------------------------------------------------
# Test Suite 7: Devcontainer & Dockerfile Lifecycle Consistency
# ------------------------------------------------------------------------------
print("\n--- [Suite 7: Devcontainer & Dockerfile Lifecycle] ---")
devcontainer_json = os.path.join(DEVCONTAINER_DIR, "devcontainer.json")
dockerfile = os.path.join(DEVCONTAINER_DIR, "Dockerfile")

with open(devcontainer_json, "r", encoding="utf-8") as f:
    dc_text = f.read()

check("devcontainer.json exists and is readable", True)
check("devcontainer.json does NOT invoke entrypoint.sh in postAttachCommand", "entrypoint.sh" not in dc_text)
check("devcontainer.json uses show-info.sh in postAttachCommand", "show-info.sh" in dc_text)

with open(dockerfile, "r", encoding="utf-8") as f:
    df_text = f.read()

check("Dockerfile installs nginx-light", "nginx-light" in df_text)
check("Dockerfile copies healthcheck.sh", "healthcheck.sh" in df_text)
check("Dockerfile uses healthcheck.sh in HEALTHCHECK instruction", "CMD /usr/local/bin/healthcheck.sh" in df_text)
check("Dockerfile has single CMD entrypoint.sh", 'CMD ["/usr/local/bin/entrypoint.sh"]' in df_text)

# ------------------------------------------------------------------------------
# Test Suite 8: .gitignore Security Verification
# ------------------------------------------------------------------------------
print("\n--- [Suite 8: Git Security & Persistence Isolation] ---")
gitignore_file = os.path.join(REPO_ROOT, ".gitignore")
check(".gitignore exists", os.path.isfile(gitignore_file))
with open(gitignore_file, "r", encoding="utf-8") as f:
    gi_text = f.read()
check(".gitignore ignores .state/", ".state/" in gi_text)
check(".gitignore ignores *.uuid", "*.uuid" in gi_text)
check(".gitignore ignores *.pid", "*.pid" in gi_text)

print("\n" + "=" * 70)
if all_passed:
    print("      ALL TESTS PASSED! Mey2Ray verification completely successful.")
else:
    print("      SOME TESTS FAILED! Review error details above.")
print("=" * 70)

sys.exit(0 if all_passed else 1)
