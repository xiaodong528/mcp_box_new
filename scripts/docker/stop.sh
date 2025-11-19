#!/bin/bash

echo "Stopping MCP Box Server..."
docker stop mcp-box-server

if [ $? -eq 0 ]; then
  echo "✅ MCP Box Server stopped successfully!"

  read -p "Do you want to remove the container? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rm mcp-box-server
    echo "✅ Container removed"

    read -p "Do you want to remove the volumes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      docker volume rm mcp-box-logs mcp-box-config
      echo "✅ Volumes removed"
    fi
  fi
else
  echo "❌ Failed to stop MCP Box Server"
  exit 1
fi
