# Agent Guidelines and Project Rules

These rules are mandatory for all AI agents and developers working on the Mey2Ray repository. Always adhere to them when writing, modifying, or refactoring code.

---

### Rule 1: No Comments in Code
* Do not include comments in any code files.
* Omit file header comments, inline comments, block comments, documentation comments, and section banners (`#`, `//`, `/* ... */`, `<!-- ... -->`).
* Shell shebang directives (`#!/bin/sh`, `#!/usr/bin/env python3`) are permitted only where required by the kernel for script execution.
* Write clean, self-explanatory variable and function names instead of adding explanatory comments.

---

### Rule 2: Architecture & Protocol Compatibility
* Preserve VLESS-over-WebSocket protocol mechanics.
* Inbound public traffic must arrive at Nginx on port 443 (HTTP/WebSocket) behind Codespaces TLS termination.
* WebSocket traffic for path `/` must proxy to local Xray instance on `127.0.0.1:8443`.
* Standard HTTP requests at `/` serve the static web dashboard.
* Requests at `/sub` deliver the Base64-encoded VLESS subscription with `Profile-Title: Mey2Ray`.
* Requests at `/healthz` return 200 OK for local container healthchecks.
* Always preserve BitTorrent blackhole blocking rules in Xray configuration.

---

### Rule 3: Single Authoritative Lifecycle & Auto-Start
* Long-running services must start via one authoritative background process managed by `postStartCommand` in `devcontainer.json`.
* Entrypoint must enforce a PID lock (`/var/run/mey2ray/mey2ray.pid`) to prevent duplicate instances.
* Terminal attach actions (`postAttachCommand`) must remain read-only (`show-info.sh`) and must never re-initialize configs or restart active processes.
* Scripts must handle signals (`SIGTERM`, `SIGINT`) gracefully.

---

### Rule 4: Persistent State Isolation & Security
* Store persistent state (UUID) in `.devcontainer/.state/uuid`.
* Never commit secrets, runtime state, UUIDs, PID files, or temporary files to git.
* All state paths must be included in `.gitignore`.
* Write state and config files atomically with strict permissions (`chmod 600`).

---

### Rule 5: Zero External Dependencies & Client-Side Privacy
* The web dashboard must remain 100% self-contained and offline.
* Do not load fonts, scripts, or stylesheets from third-party CDNs or remote APIs.
* QR codes must be rendered client-side in the browser using bundled JavaScript (`qrcode.min.js`).

---

### Rule 6: Deterministic Subscription Synchronization
* Both `/sub` and the offline Base64 subscription block must be derived from the exact same validated source of truth (`ips.txt`).
* All VLESS profile remarks must follow consistent zero-padded naming: `#Mey2Ray-XX (IP)`.
* Changes to endpoints or configurations must automatically reflect across `/sub`, terminal output, and dashboard data.

---

### Rule 7: Automated Commit & Push on Task Completion
* After each task or set of changes is completed, formulate a structured commit summary and description.
* Automatically stage changes, commit with the descriptive message, and push directly to the `main` branch of the repository (`https://github.com/meytiii/mey2ray`).
* Verify that all code conforms to project rules (including Rule 1: No Comments in Code) and all tests pass before pushing.
