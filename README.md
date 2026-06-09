# MCP Servers

Centralized Docker-based MCP (Model Context Protocol) servers for multi-client access. Each MCP tool runs in its own containerized environment and is accessible via HTTP to any consumer (OpenWebUI, Claude Code, OpenCode, etc.) on the shared Docker network.

## Directory Structure

```
mcp-servers/
├── docker-compose.yml        ← Global orchestration (paper-search)
├── paper-search/             ← Paper search MCP tool
│   ├── Dockerfile
│   └── start.sh
├── playwright/               ← Browser automation MCP tool
│   ├── docker-compose.yml
│   └── mcpo-config.json
└── (future-tools)/           ← Add new MCPs here
    ├── Dockerfile
    └── start.sh
```

## Quick Start

### Prerequisites

- Docker & Docker Compose (v2: `docker compose`)
- Existing Docker network named `shared-network`:
  ```bash
  docker network create shared-network
  ```

### Start a Specific MCP

```bash
# Start only paper-search
docker compose --profile paper-search up -d

# View status
docker compose ps
```

### Start All MCPs

```bash
docker compose --profile all up -d
```

### Stop

```bash
docker compose down
```

### View Logs

```bash
docker compose logs -f paper-search-mcpo
```

## Available MCPs

### Paper Search (`paper-search-mcpo`)

HTTP API for searching and downloading academic papers across ArXiv, PubMed, bioRxiv, medRxiv, Google Scholar, Semantic Scholar, CrossRef, and IACR.

- **Port**: 8765
- **API Docs**: `http://localhost:8765/openapi.json`
- **Network name**: `paper-search-mcpo` (within Docker network)
- **External URL**: `http://localhost:8765` (from host)
- **Profile**: `paper-search` or `all`

**Usage from OpenWebUI (on shared network)**:
```
http://paper-search-mcpo:8765
```

**Usage from host**:
```bash
curl http://localhost:8765/openapi.json
```

### Playwright Browser Automation (`playwright-mcpo`)

Headless Chromium browser automation via Playwright MCP with anti-detection stealth patches. Navigate websites, fill forms, click elements, extract data from JS-heavy pages.

> **Note**: The official Docker image only bundles Chromium. Firefox/WebKit require a custom image.

**Stealth config** (`stealth-init.js`):
- Hides `navigator.webdriver` flag
- Overrides WebGL vendor/renderer (Intel Iris on Mac)
- Sets `navigator.platform` to `MacIntel`
- Patches `HeadlessChrome` in user agent string
- Emulates Mac Safari user agent with `en-GB` locale

- **Internal port**: 8765 (mcpo proxy)
- **Host port**: 8767
- **Playwright MCP port**: 8931 (direct, for OpenCode)
- **API Docs**: `http://localhost:8767/playwright/openapi.json`
- **Network name**: `playwright-mcpo` (within Docker network)

**Start**:
```bash
cd playwright && docker compose up -d --pull always
```

**Update to latest Playwright MCP image**:
```bash
cd playwright && docker compose up -d --pull always
```

**Usage from OpenWebUI (on shared network)**:
```
http://playwright-mcpo:8765/playwright
```

**Usage from host**:
```bash
curl http://localhost:8767/playwright/openapi.json
```

## Adding a New MCP Tool

1. **Create a new subdirectory**:
   ```bash
   mkdir mcp-servers/my-tool
   ```

2. **Add `Dockerfile`** and **`start.sh`**:
   - `Dockerfile`: Build the MCP server
   - `start.sh`: Entrypoint command to start the server

3. **Update `docker-compose.yml`**:
   ```yaml
   services:
     my-tool:
       build:
         context: ./my-tool
         dockerfile: Dockerfile
       container_name: my-tool
       profiles:
         - my-tool
         - all
       ports:
         - "8766:8765"  # Adjust port (avoid conflicts)
       networks:
         - shared-network
       restart: unless-stopped
   ```

4. **Start it**:
   ```bash
   docker compose --profile my-tool up -d
   ```

## Network Details

All MCP containers are on the **`shared-network`** Docker network, allowing them to communicate with each other and with other services (OpenWebUI, OpenCode, etc.) using container hostnames.

- **Network name**: `shared-network` (must be created externally)
- **Inspect**: `docker network inspect shared-network`

## Troubleshooting

### Container fails to start
```bash
docker compose logs paper-search-mcpo
```

### Network not found
```bash
docker network create shared-network
```

### Port already in use
Modify the port mapping in `docker-compose.yml` and restart.

### Permission issues
Ensure your user can access Docker:
```bash
docker ps
```

## Architecture

**Paper Search** (built-in mcpo):
```
MCP Server (uv run)
      ↓
   mcpo (HTTP wrapper, same container)
      ↓
  HTTP API (port 8765)
      ↓
  shared-network
```

**Playwright** (separate containers):
```
mcr.microsoft.com/playwright/mcp (official image, port 8931)
      ↓
   mcpo proxy (separate container)
      ↓
  HTTP API (port 8765)
      ↓
  shared-network
```

Both patterns expose OpenAPI endpoints consumable by OpenWebUI, OpenCode, Claude Code, etc.
