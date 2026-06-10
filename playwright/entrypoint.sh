#!/bin/sh
# Start cleanup monitor in background, then run the MCP server
/app/cleanup.sh &
exec "$@"
