#!/bin/bash
set -e

echo "Starting mcpo on port 8765..."
echo "paper-search-mcp server: /app/paper-search-mcp"
echo "Downloads path: /app/paper-search-mcp/downloads"

uvx mcpo -p 8765 -- uv run --directory /app/paper-search-mcp -m paper_search_mcp.server
