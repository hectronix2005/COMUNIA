#!/usr/bin/env bash
# Copia diaria de la base de COMUNIA en asus (crontab de asus_2025, 3:30).
# Por cron y no por systemd --user: este arrancó antes de entrar en el grupo docker
# y asus no trae sg/newgrp; cron abre cada tarea con los grupos actuales.
# Único destino: Google Drive (decisión de Héctor, 18-oct-2026).
#  1. pg_dump -Fc desde el contenedor db a un archivo temporal en ~/backups/comunia.
#  2. Prueba: pg_restore --list sobre la copia; si falla, no se sube nada.
#  3. Cifrado gpg (AES-256, clave en ~/.config/comunia-backup/passphrase; Héctor
#     guarda otra copia fuera de asus; también en el Llavero del Air) y subida al
#     Google Drive de hectorn.personal@gmail.com (remote rclone "gdrive-personal",
#     el mismo de Prestandonos; carpeta COMUNIA-backups); allí se guardan 30 días.
#  4. Si la subida va bien, no queda nada en asus. Si falla, la copia se queda en
#     ~/backups/comunia para no perderla.
# Restaurar (con web parada):
#   gpg -d comunia-AAAAMMDD-HHMM.dump.gpg > comunia-AAAAMMDD-HHMM.dump
#   docker exec -i comunia-db-1 pg_restore --clean --if-exists --no-owner --no-acl \
#     -U comunia -d comunia_production < comunia-AAAAMMDD-HHMM.dump
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/bin:/bin"

DIR="$HOME/backups/comunia"
PASS="$HOME/.config/comunia-backup/passphrase"
REMOTE="gdrive-personal:COMUNIA-backups"  # Drive de hectorn.personal@gmail.com (antes gdrive = Drive de Picap)
LOG="$HOME/services/comunia-backup.log"
# «<epoch> OK|ERROR …» de la última pasada; lo lee vigila-flota (Tmux, en el Air).
ESTADO="$HOME/services/comunia-backup.estado"
DB=(docker exec comunia-db-1)

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
estado() { echo "$(date +%s) $*" > "$ESTADO"; }
trap '[ $? -ne 0 ] && estado "ERROR: la copia falló (ver $LOG)"' EXIT

umask 077
mkdir -p "$DIR"
exec 9>"$DIR/.lock"
flock -n 9 || { log "ya hay una copia en curso"; exit 0; }

F="$DIR/comunia-$(date +%Y%m%d-%H%M).dump"
"${DB[@]}" pg_dump -Fc -U comunia comunia_production > "$F.tmp"
docker exec -i comunia-db-1 pg_restore --list < "$F.tmp" > /dev/null \
  || { log "ERROR: la copia no pasa pg_restore --list"; rm -f "$F.tmp"; exit 1; }
mv "$F.tmp" "$F"
USERS=$("${DB[@]}" psql -U comunia -d comunia_production -Atc "select count(*) from users")

gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$PASS" \
  --symmetric --cipher-algo AES256 -o "$F.gpg" "$F"
if rclone copy "$F.gpg" "$REMOTE" --quiet; then
  rclone delete "$REMOTE" --min-age 30d --quiet || true
  rm -f "$F" "$F.gpg"
  log "subida a Drive: $REMOTE/$(basename "$F.gpg") usuarios=$USERS"
  estado "OK $(basename "$F.gpg") usuarios=$USERS"
else
  rm -f "$F.gpg"
  log "ERROR: no se pudo subir a Drive; la copia queda en $F"
  exit 1
fi
