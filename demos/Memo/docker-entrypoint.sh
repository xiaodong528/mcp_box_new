#!/bin/bash
set -e

echo "========================================"
echo "Memo Application Starting..."
echo "========================================"

# Initialize database if not exists
echo "[1/4] Initializing database..."
python -c "from backend.db import init_db; init_db()" || {
    echo "ERROR: Failed to initialize database"
    exit 1
}
echo "✓ Database initialized at ${MEMO_DB_PATH}"

# Start API Server (background)
echo "[2/4] Starting API Server (port 48000)..."
uvicorn backend.api:app --host 0.0.0.0 --port 48000 &
API_PID=$!
echo "✓ API Server started (PID: $API_PID)"

# Wait for API server to be ready
echo "[3/4] Waiting for API Server to be ready..."
for i in {1..10}; do
    if curl -s http://localhost:48000/health > /dev/null 2>&1; then
        echo "✓ API Server is ready"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "ERROR: API Server failed to start"
        exit 1
    fi
    echo "   Waiting... ($i/10)"
    sleep 1
done

# Start MCP SSE Server (background)
echo "[4/4] Starting MCP SSE Server (port 48001)..."
python -m backend.mcp_sse_server --host 0.0.0.0 --port 48001 --api-url http://localhost:48000 &
MCP_PID=$!
echo "✓ MCP SSE Server started (PID: $MCP_PID)"

# Start Frontend Static Server (foreground)
echo "[5/5] Starting Frontend Server (port 48002)..."
cd frontend
python -m http.server 48002 &
FRONTEND_PID=$!

echo ""
echo "========================================"
echo "✓ All services started successfully!"
echo "========================================"
echo "API Server:      http://localhost:48000"
echo "API Docs:        http://localhost:48000/docs"
echo "MCP SSE Server:  http://localhost:48001/sse"
echo "Frontend:        http://localhost:48002"
echo "========================================"

# Trap signals to gracefully shutdown
trap "echo 'Shutting down...'; kill $API_PID $MCP_PID $FRONTEND_PID 2>/dev/null; exit 0" SIGTERM SIGINT

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
