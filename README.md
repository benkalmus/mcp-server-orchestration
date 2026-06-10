# MCP Servers

Centralized MCP (Model Context Protocol) servers for multi-client access. Each MCP runs containerized or as a systemd user service, accessible via HTTP to any consumer (OpenWebUI, OpenCode, Claude Code, etc.) on the shared Docker network.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Host (Ubuntu 25.10)                                            │
│                                                                 │
│  ┌──────────────────────┐   ┌─────────────────────────────────┐ │
│  │ systemd user services│   │ Docker containers                │ │
│  │                      │   │                                   │ │
│  │ chromium-cdp         │   │ playwright-mcp (tontoko fork)    │ │
│  │  :9222 (CDP)         │   │  :8931 (MCP Streamable HTTP)    │ │
│  │  └─ persistent       │   │  └─ isolated headless Chromium   │ │
│  │     headless Chromium│   │     with stealth patches +       │ │
│  │     with auth cookies│   │     browser cleanup sidecar      │ │
│  │                      │   │                                   │ │
│  │ playwright-mcp-auth  │   │ paper-search-mcpo                │ │
│  │  :8932 (MCP HTTP)   │   │  :8765 (OpenAPI/mcpo proxy)     │ │
│  │  └─ connects to CDP │   │  └─ academic paper search +       │ │
│  │     (shares auth     │   │     download                      │ │
│  │      session)        │   │                                   │ │
│  └──────────────────────┘   └─────────────────────────────────┘ │
│            │                            │                       │
│            └──────────┬─────────────────┘                       │
│                       │ 172.20.0.1 (host gateway)               │
└───────────────────────┼─────────────────────────────────────────┘
                        │
              shared-network (Docker)
                        │
         ┌──────────────┴──────────────┐
         │  OpenWebUI / other consumers │
         └─────────────────────────────┘
```

## Directory Structure

```
mcp-servers/
├── README.md                          ← This file
├── docker-compose.yml                 ← Paper-search orchestration
├── paper-search/                      ← Academic paper search MCP
│   ├── Dockerfile
│   ├── start.sh
│   └── paper-search-mcp/
└── playwright/                        ← Browser automation MCPs
    ├── docker-compose.yml             ← Tontoko fork container (port 8931)
    ├── Dockerfile.tontoko             ← Builds tontoko/fast-playwright-mcp from source
    ├── entrypoint.sh                  ← Starts cleanup sidecar + MCP server
    ├── cleanup.sh                     ← Kills Chromium processes older than 20min
    ├── config.json                    ← Browser config: stealth args, viewport, locale
    ├── stealth-init.js                ← JS stealth patches (webdriver, WebGL, user agent)
    ├── mcpo-config.json               ← mcpo proxy config for OpenWebUI
    ├── chromium-cdp.service           ← Systemd: persistent headless Chromium on port 9222
    ├── playwright-mcp-auth.service    ← Systemd: MCP auth server on port 8932
    ├── sync-browser-auth              ← Script: rsyncs snap Chromium session to auth profile
    ├── fast-playwright-mcp/           ← Tontoko fork source (submodule/checkout)
    └── playwright-mcp-ultra/          ← Alternative MCP build (experimental)
```

## Prerequisites

- Docker and Docker Compose v2 (`docker compose`)
- Docker network named `shared-network`:
  ```bash
  docker network create shared-network
  ```
- Node.js 18+ (for npx, used by systemd services)
- Playwright Chromium installed:
  ```bash
  npx playwright install chromium
  ```
- Snap Chromium (for login sessions that get synced to headless auth profile)

## Setup: Playwright Browser Automation

The Playwright MCP has two modes: **browser-lite** (isolated, no auth) and **browser-auth** (shares your logged-in session).

### 1. browser-lite: Isolated Headless Browsing (Docker, port 8931)

Uses the tontoko/fast-playwright-mcp fork with stealth patches, token-optimized output, and a cleanup sidecar.

**Start**:
```bash
cd mcp-servers/playwright && docker compose up -d --pull always
```

**Usage**:
- OpenCode (remote MCP): `http://localhost:8931/mcp`
- OpenWebUI (container name, same network): `http://playwright-mcp:8931/mcp`
- From Docker containers: `http://playwright-mcp:8931/mcp`

**Features**:
- Token-optimized output (diff mode, batch execute, omit snapshots)
- Stealth patches: hides `navigator.webdriver`, overrides WebGL vendor/renderer, patches `HeadlessChrome` in user agent, emulates Mac Safari with `en-GB` locale
- Cleanup sidecar: kills Chromium processes older than 20 minutes
- `--isolated` flag for concurrent sessions without cross-contamination

### 2. browser-auth: Authenticated Browsing (systemd, port 8932)

Connects to a persistent headless Chromium via CDP that shares your logged-in sessions (Facebook, eBay, etc.). Runs as two systemd user services.

#### Step 1: Install systemd services

```bash
# Copy service files
cp mcp-servers/playwright/chromium-cdp.service ~/.config/systemd/user/
cp mcp-servers/playwright/playwright-mcp-auth.service ~/.config/systemd/user/

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable chromium-cdp.service playwright-mcp-auth.service
systemctl --user start chromium-cdp.service
# playwright-mcp-auth has BindsTo=chromium-cdp, so it starts after
systemctl --user start playwright-mcp-auth.service
```

#### Step 2: Install the sync script

```bash
cp mcp-servers/playwright/sync-browser-auth ~/.local/bin/
chmod +x ~/.local/bin/sync-browser-auth
```

#### Step 3: Sync your login sessions

Log into sites (Facebook, eBay, etc.) in your normal snap Chromium browser, then run:

```bash
sync-browser-auth
```

This rsyncs cookies and session data from `~/snap/chromium/common/chromium/Default/` to `~/.config/chromium-auth/Default/`, excluding caches and lock files.

Then restart the CDP Chromium to pick up the new session data:

```bash
systemctl --user restart chromium-cdp.service
```

`playwright-mcp-auth` will auto-restart (via `BindsTo`).

#### Usage

- OpenCode (remote MCP): `http://localhost:8932/mcp`
- OpenWebUI (`host.docker.internal`): `http://host.docker.internal:8932/mcp`

### 3. Configure OpenCode

In `~/.config/opencode/config.json`:

```json
{
  "mcp": {
    "browser-lite": {
      "type": "remote",
      "url": "http://localhost:8931/mcp",
      "enabled": true
    },
    "browser-auth": {
      "type": "remote",
      "url": "http://localhost:8932/mcp",
      "enabled": true
    }
  }
}
```

### 4. Configure OpenWebUI

In OpenWebUI Admin, Settings, External Tools, add two MCP servers:

| Name | Type | URL |
|------|------|-----|
| `browser-lite` | MCP (Streamable HTTP) | `http://playwright-mcp:8931/mcp` |
| `browser-auth` | MCP (Streamable HTTP) | `http://host.docker.internal:8932/mcp` |

- `browser-lite` uses the Docker container name (`playwright-mcp`) since it runs on `shared-network`.
- `browser-auth` uses `host.docker.internal` since it runs on the host (systemd). OpenWebUI's compose already has `extra_hosts: host.docker.internal:host-gateway`, which dynamically resolves to the host IP after restarts.

## Setup: Paper Search

```bash
docker compose --profile paper-search up -d
```

- **Port**: 8765
- **API Docs**: `http://localhost:8765/openapi.json`
- **From Docker**: `http://paper-search-mcpo:8765`

## When to Use Which Browser MCP

| Task | Use | Why |
|------|-----|-----|
| General web browsing, scraping, research | browser-lite | Isolated, token-optimized, stealth patches, no login needed |
| Amazon UK, AliExpress, brand stores | browser-lite | Public access, stealth bypasses basic bot detection |
| eBay UK search | browser-lite (homepage-first pattern) | Navigate to ebay.co.uk first, accept cookies, wait 3s, then search |
| Facebook Marketplace | browser-auth | Requires login |
| eBay bid history, saved searches | browser-auth | Requires login |
| Any site behind auth wall | browser-auth | Shares your logged-in session |

### eBay Homepage-First Pattern

Direct navigation to eBay search URLs triggers Akamai CAPTCHA. Always navigate to `https://www.ebay.co.uk/` first, accept cookie consent, wait 3 seconds, then navigate to the search URL. This establishes a session cookie that bypasses the challenge.

## Maintenance

### Sync auth sessions after logging into new sites

```bash
sync-browser-auth
systemctl --user restart chromium-cdp.service
```

### Restart services

```bash
systemctl --user restart chromium-cdp.service        # restarts both (BindsTo)
systemctl --user restart playwright-mcp-auth.service  # restart MCP server only
```

### Check service status

```bash
systemctl --user status chromium-cdp.service
systemctl --user status playwright-mcp-auth.service
```

### View logs

```bash
journalctl --user -u chromium-cdp.service -f
journalctl --user -u playwright-mcp-auth.service -f
docker compose -f mcp-servers/playwright/docker-compose.yml logs -f
```

### Update tontoko fork (browser-lite)

```bash
cd mcp-servers/playwright && docker compose up -d --pull always --build
```

### Update playwright-mcp-auth (browser-auth)

The systemd service uses `npx -y @playwright/mcp@latest`, so it pulls the latest version on each start. To force update:

```bash
systemctl --user restart playwright-mcp-auth.service
```

## Troubleshooting

### browser-auth returns "Access is only allowed at localhost"

The `--allowed-hosts '*'` flag is required when accessing from non-localhost IPs (Docker containers). Verify it is present in the service file:

```
ExecStart=npx -y @playwright/mcp@latest --cdp-endpoint=http://127.0.0.1:9222 --port 8932 --host 0.0.0.0 --allowed-hosts '*'
```

### Node.js DNS resolves localhost to IPv6

On this system, Node.js resolves `localhost` to `::1`. Always use `127.0.0.1` in MCP URLs and CDP endpoints.

### Snap Chromium crashes in headless mode

The snap-packaged Chromium does not work in headless mode. The systemd service uses Playwright's bundled Chromium instead, located at `~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome`.

### chromium-cdp service fails to start

Check the Chromium path in the service file matches the installed version:

```bash
ls ~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome
```

If the version changed (after `npx playwright install chromium`), update the path in `chromium-cdp.service` and reload.

### Port conflicts

- 8931: browser-lite (Docker)
- 8932: browser-auth (systemd)
- 9222: Chromium CDP (systemd)
- 8765: paper-search (Docker)

## Key Files

| File | Purpose |
|------|---------|
| `playwright/chromium-cdp.service` | Systemd service: persistent headless Chromium with CDP on port 9222 |
| `playwright/playwright-mcp-auth.service` | Systemd service: MCP auth server on port 8932, connects to CDP |
| `playwright/sync-browser-auth` | Shell script: rsyncs snap Chromium session to auth profile |
| `playwright/docker-compose.yml` | Docker: tontoko fork on port 8931 |
| `playwright/Dockerfile.tontoko` | Builds tontoko/fast-playwright-mcp from source with bun |
| `playwright/config.json` | Browser config: stealth args, viewport, locale, user agent |
| `playwright/stealth-init.js` | JS stealth patches evaluated before page scripts |
| `playwright/entrypoint.sh` | Container entrypoint: cleanup sidecar + MCP server |
| `playwright/cleanup.sh` | Kills Chromium processes older than 20 minutes |
