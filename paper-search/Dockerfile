FROM python:3.13-slim

# Install uv
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Set working directory
WORKDIR /app

# Copy paper-search-mcp from git submodule
COPY paper-search-mcp /app/paper-search-mcp

# Install dependencies
RUN cd /app/paper-search-mcp && uv sync

# Expose port
EXPOSE 8765

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8765/openapi.json || exit 1

# Start mcpo
ENTRYPOINT ["/app/start.sh"]
