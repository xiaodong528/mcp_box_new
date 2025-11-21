# Memo Application - Single Container Multi-Service
# Architecture: API Server + MCP SSE Server + Frontend Static Server

FROM --platform=linux/amd64 python:3.12-slim

# Set working directory
WORKDIR /app

# Install system dependencies (if needed in future)
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    curl \
    wget \
    netcat-traditional \
    iputils-ping \
    net-tools \
    procps \
    lsof \
    telnet \
    dnsutils \
    htop \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY backend/ backend/
COPY frontend/ frontend/

# Create data directory for SQLite database
RUN mkdir -p /app/data

# Environment variables
ENV MEMO_DB_PATH=/app/data/memo.db \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Expose ports
# 48000: API Server (FastAPI)
# 48001: MCP SSE Server (FastMCP)
# 48002: Frontend Static Server
EXPOSE 48000 48001 48002

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Health check for API server
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:48000/health || exit 1

# Start all services
CMD ["/docker-entrypoint.sh"]
