#!/bin/bash

show_usage() {
  echo "Usage: $0 {list|inspect|backup|restore|clean}"
  echo ""
  echo "Commands:"
  echo "  list      - List all MCP Box volumes"
  echo "  inspect   - Inspect volume details"
  echo "  backup    - Backup volumes to ./backups/"
  echo "  restore   - Restore volumes from backup"
  echo "  clean     - Remove all MCP Box volumes (WARNING: data loss!)"
}

list_volumes() {
  echo "📊 MCP Box Volumes:"
  docker volume ls | grep mcp-box
}

inspect_volumes() {
  echo "📋 Volume Details:"
  echo ""
  echo "=== Logs Volume ==="
  docker volume inspect mcp-box-logs
  echo ""
  echo "=== Config Volume ==="
  docker volume inspect mcp-box-config
}

backup_volumes() {
  BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUP_DIR"

  echo "💾 Backing up volumes to $BACKUP_DIR..."

  # Backup logs
  docker run --rm -v mcp-box-logs:/source -v "$(pwd)/$BACKUP_DIR":/backup alpine \
    tar czf /backup/logs.tar.gz -C /source .

  # Backup config
  docker run --rm -v mcp-box-config:/source -v "$(pwd)/$BACKUP_DIR":/backup alpine \
    tar czf /backup/config.tar.gz -C /source .

  echo "✅ Backup completed: $BACKUP_DIR"
}

restore_volumes() {
  echo "Available backups:"
  ls -1 ./backups/ 2>/dev/null || { echo "No backups found"; exit 1; }
  echo ""
  read -p "Enter backup directory name: " backup_name

  BACKUP_DIR="./backups/$backup_name"
  if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup directory not found: $BACKUP_DIR"
    exit 1
  fi

  echo "♻️  Restoring from $BACKUP_DIR..."

  # Restore logs
  if [ -f "$BACKUP_DIR/logs.tar.gz" ]; then
    docker run --rm -v mcp-box-logs:/target -v "$(pwd)/$BACKUP_DIR":/backup alpine \
      tar xzf /backup/logs.tar.gz -C /target
    echo "  ✅ Logs restored"
  fi

  # Restore config
  if [ -f "$BACKUP_DIR/config.tar.gz" ]; then
    docker run --rm -v mcp-box-config:/target -v "$(pwd)/$BACKUP_DIR":/backup alpine \
      tar xzf /backup/config.tar.gz -C /target
    echo "  ✅ Config restored"
  fi

  echo "✅ Restore completed"
}

clean_volumes() {
  echo "⚠️  WARNING: This will delete all MCP Box volumes!"
  read -p "Are you sure? Type 'yes' to confirm: " confirmation

  if [ "$confirmation" = "yes" ]; then
    docker volume rm mcp-box-logs mcp-box-config 2>/dev/null
    echo "✅ Volumes removed"
  else
    echo "Cancelled"
  fi
}

case "$1" in
  list)
    list_volumes
    ;;
  inspect)
    inspect_volumes
    ;;
  backup)
    backup_volumes
    ;;
  restore)
    restore_volumes
    ;;
  clean)
    clean_volumes
    ;;
  *)
    show_usage
    exit 1
    ;;
esac
