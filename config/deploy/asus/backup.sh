#!/usr/bin/env bash
# Copia diaria de la base de COMUNIA en asus (crontab de asus_2025, 3:30).
# Por cron y no por systemd --user: este arrancó antes de entrar en el grupo docker
# y asus no trae sg/newgrp; cron abre cada tarea con los grupos actuales.
#  1. pg_dump -Fc desde el contenedor db a ~/backups/comunia (se guardan 7).
#  2. Prueba: pg_restore --list sobre la copia; si falla, no se envía nada.
#  3. Envío a ubuntu (~/backups/comunia, por Tailscale SSH); allí se guardan 30 días.
#  4. Copia fuera de casa: cifrada con gpg (AES-256, clave en
#     ~/.config/comunia-backup/passphrase; Héctor guarda otra copia fuera de asus)
#     y subida a Google Drive (remote rclone "gdrive", scope drive.file,
#     carpeta COMUNIA-backups); allí se guardan 30 días.
# Un fallo en un destino no impide el otro; el guion sale con error si alguno falla.
# Restaurar (con web parada):
#   docker exec -i comunia-db-1 pg_restore --clean --if-exists --no-owner --no-acl \
#     -U comunia -d comunia_production < comunia-AAAAMMDD-HHMM.dump
#   (desde Drive, antes: gpg -d comunia-AAAAMMDD-HHMM.dump.gpg > comunia-AAAAMMDD-HHMM.dump)
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/bin:/bin"

DIR="$HOME/backups/comunia"
DEST_HOST="alejandro@100.89.116.66"
DEST_DIR="backups/comunia"
PASS="$HOME/.config/comunia-backup/passphrase"
REMOTE="gdrive:COMUNIA-backups"
LOG="$HOME/services/comunia-backup.log"
DB=(docker exec comunia-db-1)

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

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
log "copia local OK: $(basename "$F") $(du -h "$F" | cut -f1) usuarios=$USERS"

ls -1t "$DIR"/comunia-*.dump | tail -n +8 | xargs -r rm --

FAILED=0

if rsync -e "ssh -o BatchMode=yes -o ConnectTimeout=20" "$F" "$DEST_HOST:$DEST_DIR/"; then
  ssh -o BatchMode=yes "$DEST_HOST" "find $DEST_DIR -name 'comunia-*.dump' -mtime +30 -delete"
  log "enviada a ubuntu: $(basename "$F")"
else
  log "ERROR: no se pudo enviar a ubuntu"
  FAILED=1
fi

gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$PASS" \
  --symmetric --cipher-algo AES256 -o "$F.gpg" "$F"
if rclone copy "$F.gpg" "$REMOTE" --quiet; then
  rclone delete "$REMOTE" --min-age 30d --quiet || true
  log "subida a Drive: $REMOTE/$(basename "$F.gpg")"
else
  log "ERROR: no se pudo subir a Drive"
  FAILED=1
fi
rm -f "$F.gpg"

exit "$FAILED"
