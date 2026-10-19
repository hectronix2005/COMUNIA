#!/usr/bin/env bash
# Copia diaria de la base de COMUNIA en asus (timer comunia-backup.timer).
#  1. pg_dump -Fc desde el contenedor db a ~/backups/comunia (se guardan 7).
#  2. Prueba: pg_restore --list sobre la copia; si falla, no se envía nada.
#  3. Envío a ubuntu (~/backups/comunia, por Tailscale SSH); allí se guardan 30 días.
# Restaurar (con web parada):
#   docker exec -i comunia-db-1 pg_restore --clean --if-exists --no-owner --no-acl \
#     -U comunia -d comunia_production < comunia-AAAAMMDD-HHMM.dump
set -euo pipefail

# El systemd --user de asus arrancó antes de entrar en el grupo docker: relanzar con sg.
if ! id -nG | grep -qw docker; then
  exec sg docker -c "$(printf '%q' "$0")"
fi

DIR="$HOME/backups/comunia"
DEST_HOST="alejandro@100.89.116.66"
DEST_DIR="backups/comunia"
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

rsync -e "ssh -o BatchMode=yes -o ConnectTimeout=20" "$F" "$DEST_HOST:$DEST_DIR/" \
  || { log "ERROR: no se pudo enviar a ubuntu"; exit 1; }
ssh -o BatchMode=yes "$DEST_HOST" "find $DEST_DIR -name 'comunia-*.dump' -mtime +30 -delete"
log "enviada a ubuntu: $(basename "$F")"
