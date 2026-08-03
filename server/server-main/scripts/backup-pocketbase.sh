#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SERVER_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_DIR=${BACKUP_DIR:-"$SERVER_DIR/backups/pocketbase"}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
ARCHIVE="pocketbase-$STAMP.tar.gz"
STOPPED=0

case "$BACKUP_DIR" in
  "$SERVER_DIR"/*) ;;
  *)
    echo "Refusing to use a backup directory outside $SERVER_DIR" >&2
    exit 1
    ;;
esac

mkdir -p "$BACKUP_DIR"

start_services() {
  if [ "$STOPPED" -eq 1 ]; then
    cd "$SERVER_DIR"
    docker compose up -d pocketbase api >/dev/null
  fi
}
trap start_services EXIT INT TERM

cd "$SERVER_DIR"
docker compose stop api pocketbase
STOPPED=1

docker run --rm \
  --volumes-from pocketbase \
  -v "$BACKUP_DIR:/backup" \
  caddy:2-alpine \
  tar -czf "/backup/$ARCHIVE" -C /pb/pb_data .

sha256sum "$BACKUP_DIR/$ARCHIVE" > "$BACKUP_DIR/$ARCHIVE.sha256"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'pocketbase-*.tar.gz' -mtime +30 -delete
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'pocketbase-*.tar.gz.sha256' -mtime +30 -delete

start_services
STOPPED=0
trap - EXIT INT TERM

echo "PocketBase backup: $BACKUP_DIR/$ARCHIVE"
echo "Checksum: $BACKUP_DIR/$ARCHIVE.sha256"
