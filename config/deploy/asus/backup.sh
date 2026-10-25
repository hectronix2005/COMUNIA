#!/usr/bin/env bash
# Copia diaria de la base de COMUNIA en asus (crontab de asus_2025, 3:45; Rival sube a las 3:30 al mismo remoto).
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
#  5. Los adjuntos guardados en disco (~/services/comunia-storage: servicio «local» de ActiveStorage)
#     van en otro tar cifrado. Los de R2 no se copian aquí.
#  6. Las evidencias de DENUNCIAPP (~/services/denuncias-evidencia) van en un tar aparte, cifrado
#     con la misma clave gpg. Sus tablas ya están en el dump. Los originales de las fotos, además,
#     llevan AES-GCM con DENUNCIAS_CLAVE (app.env y Llavero del Air, nunca en Drive): con solo
#     la copia de Drive no se pueden abrir.
# Restaurar (con web parada):
#   gpg -d comunia-AAAAMMDD-HHMM.dump.gpg > comunia-AAAAMMDD-HHMM.dump
#   docker exec -i comunia-db-1 pg_restore --clean --if-exists --no-owner --no-acl \
#     -U comunia -d comunia_production < comunia-AAAAMMDD-HHMM.dump
#   gpg -d archivos-AAAAMMDD-HHMM.tar.gpg | tar -C ~/services/comunia-storage -xf -
#   gpg -d denuncias-AAAAMMDD-HHMM.tar.gpg | tar -C ~/services/denuncias-evidencia -xf -
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/bin:/bin"

DIR="$HOME/backups/comunia"
EVIDENCIA="$HOME/services/denuncias-evidencia"
ARCHIVOS="$HOME/services/comunia-storage"
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

SELLO=$(date +%Y%m%d-%H%M)
F="$DIR/comunia-$SELLO.dump"
"${DB[@]}" pg_dump -Fc -U comunia comunia_production > "$F.tmp"
docker exec -i comunia-db-1 pg_restore --list < "$F.tmp" > /dev/null \
  || { log "ERROR: la copia no pasa pg_restore --list"; rm -f "$F.tmp"; exit 1; }
mv "$F.tmp" "$F"
USERS=$("${DB[@]}" psql -U comunia -d comunia_production -Atc "select count(*) from users")

cifrar() { gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$PASS" \
  --symmetric --cipher-algo AES256 -o "$1"; }
cifrar "$F.gpg" < "$F"
if rclone copy "$F.gpg" "$REMOTE" --quiet; then
  rm -f "$F" "$F.gpg"
  log "subida a Drive: $REMOTE/$(basename "$F.gpg") usuarios=$USERS"
else
  rm -f "$F.gpg"
  log "ERROR: no se pudo subir a Drive; la copia queda en $F"
  exit 1
fi

if [ -n "$(ls -A "$ARCHIVOS" 2>/dev/null)" ]; then
  A="$DIR/archivos-$SELLO.tar.gpg"
  tar -C "$ARCHIVOS" -cf - . | cifrar "$A"
  rclone copy "$A" "$REMOTE" --quiet \
    || { log "ERROR: no se pudieron subir los archivos; quedan en $A"; exit 1; }
  rm -f "$A"
  log "subida a Drive: $REMOTE/$(basename "$A")"
fi

if [ -n "$(ls -A "$EVIDENCIA" 2>/dev/null)" ]; then
  E="$DIR/denuncias-$SELLO.tar.gpg"
  tar -C "$EVIDENCIA" -cf - . | cifrar "$E"
  rclone copy "$E" "$REMOTE" --quiet \
    || { log "ERROR: no se pudieron subir las evidencias; quedan en $E"; exit 1; }
  rm -f "$E"
  log "subida a Drive: $REMOTE/$(basename "$E")"
fi

rclone delete "$REMOTE" --min-age 30d --quiet || true
estado "OK $(basename "$F.gpg") usuarios=$USERS"
