#!/usr/bin/env bash
# Copia diaria de la base de COMUNIA en asus (crontab de asus_2025, 3:45; Rival sube a las 3:30 al mismo remoto).
# Por cron y no por systemd --user: este arrancó antes de entrar en el grupo docker
# y asus no trae sg/newgrp; cron abre cada tarea con los grupos actuales.
# Destinos (1-nov-2026): el principal es el bucket «comunia-copias» de Cloudflare R2 (curl con firma
# S3; clave propia, restringida a ese bucket, en ~/.config/comunia-backup/r2-copias.env; una regla
# del bucket borra lo de más de 30 días). Google Drive (rclone «gdrive-personal») queda de extra:
# si falla, solo deja un AVISO en el log. Héctor no quiere depender del cliente OAuth de rclone,
# que Google retira en 2026. Hasta el 1-nov el único destino era Drive (decisión del 18-oct-2026).
#  1. pg_dump -Fc desde el contenedor db a un archivo temporal en ~/backups/comunia.
#  2. Prueba: pg_restore --list sobre la copia; si falla, no se sube nada.
#  3. Cifrado gpg (AES-256, clave en ~/.config/comunia-backup/passphrase; Héctor
#     guarda otra copia fuera de asus; también en el Llavero del Air) y subida a R2 y a Drive
#     (Drive de hectorn.personal@gmail.com, carpeta COMUNIA-backups; allí también 30 días).
#  4. Si la subida a R2 va bien, no queda nada en asus. Si falla, la copia cifrada se queda en
#     ~/backups/comunia para no perderla, y la pasada termina en ERROR.
#  5. Los adjuntos guardados en disco (~/services/comunia-storage: servicio «local» de ActiveStorage)
#     van en otro tar cifrado.
#  5b. Los de Cloudflare R2 (servicio «cloudflare», donde van los que se suben desde el 18-oct) se bajan
#     con las credenciales de la app (app.env; no se guardan en rclone.conf) y van en otro tar cifrado
#     (1-nov-2026: hasta entonces no tenían copia).
#  6. Las evidencias de DENUNCIAPP (~/services/denuncias-evidencia) van en un tar aparte, cifrado
#     con la misma clave gpg. Sus tablas ya están en el dump. Los originales de las fotos, además,
#     llevan AES-GCM con DENUNCIAS_CLAVE (app.env y Llavero del Air, nunca en las copias): con solo
#     la copia no se pueden abrir.
# Bajar de R2 (la clave se puede rehacer en Cloudflare › R2 › API tokens si se pierde asus):
#   set -a; . ~/.config/comunia-backup/r2-copias.env; set +a
#   S3=(curl --fail -sS --aws-sigv4 "aws:amz:auto:s3" --user "$COPIAS_R2_KEY:$COPIAS_R2_SECRET")
#   "${S3[@]}" "$COPIAS_R2_ENDPOINT/$COPIAS_R2_BUCKET?list-type=2"        # lista (XML)
#   "${S3[@]}" -O "$COPIAS_R2_ENDPOINT/$COPIAS_R2_BUCKET/comunia-AAAAMMDD-HHMM.dump.gpg"
# Restaurar (con web parada):
#   gpg -d comunia-AAAAMMDD-HHMM.dump.gpg > comunia-AAAAMMDD-HHMM.dump
#   docker exec -i comunia-db-1 pg_restore --clean --if-exists --no-owner --no-acl \
#     -U comunia -d comunia_production < comunia-AAAAMMDD-HHMM.dump
#   gpg -d archivos-AAAAMMDD-HHMM.tar.gpg | tar -C ~/services/comunia-storage -xf -
#   gpg -d r2-AAAAMMDD-HHMM.tar.gpg | tar -C /tmp/r2 -xf -   y luego: rclone copy /tmp/r2 r2:<bucket> (mismas variables que r2_bajar)
#   gpg -d denuncias-AAAAMMDD-HHMM.tar.gpg | tar -C ~/services/denuncias-evidencia -xf -
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/bin:/bin"

DIR="$HOME/backups/comunia"
EVIDENCIA="$HOME/services/denuncias-evidencia"
ARCHIVOS="$HOME/services/comunia-storage"
PASS="$HOME/.config/comunia-backup/passphrase"
APPENV="$HOME/services/comunia-secrets/app.env"
COPIAS="$HOME/.config/comunia-backup/r2-copias.env"
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

# En un subshell: la clave de las copias no sale de aquí.
r2_subir() (
  set -a; . "$COPIAS"; set +a
  curl --fail -sS --retry 3 --aws-sigv4 "aws:amz:auto:s3" --user "$COPIAS_R2_KEY:$COPIAS_R2_SECRET" \
    -T "$1" "$COPIAS_R2_ENDPOINT/$COPIAS_R2_BUCKET/$(basename "$1")" -o /dev/null
)
# R2 es obligatorio; Drive, un extra mientras funcione.
subir() {
  local f="$1" n
  n=$(basename "$f")
  r2_subir "$f" || { log "ERROR: no se pudo subir $n a R2; queda en $f"; exit 1; }
  if rclone copy "$f" "$REMOTE" --quiet; then
    log "subida a R2 y Drive: $n ${2:-}"
  else
    log "AVISO: $n subió a R2 pero no a Drive ($REMOTE)"
  fi
  rm -f "$f"
}

cifrar "$F.gpg" < "$F"
rm -f "$F"
subir "$F.gpg" "usuarios=$USERS"

if [ -n "$(ls -A "$ARCHIVOS" 2>/dev/null)" ]; then
  A="$DIR/archivos-$SELLO.tar.gpg"
  tar -C "$ARCHIVOS" -cf - . | cifrar "$A"
  subir "$A"
fi

# En un subshell: las variables de app.env no salen de aquí.
r2_bajar() (
  set -a; . "$APPENV"; set +a
  export RCLONE_CONFIG_R2_TYPE=s3 RCLONE_CONFIG_R2_PROVIDER=Cloudflare RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true \
    RCLONE_CONFIG_R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    RCLONE_CONFIG_R2_ENDPOINT="$R2_ENDPOINT"
  rclone copy "r2:$R2_BUCKET" "$1" --quiet
)
R2DIR="$DIR/r2-$SELLO"
mkdir -p "$R2DIR"
r2_bajar "$R2DIR" || { log "ERROR: no se pudieron bajar los archivos de R2"; rm -rf "$R2DIR"; exit 1; }
if [ -n "$(ls -A "$R2DIR")" ]; then
  R="$DIR/r2-$SELLO.tar.gpg"
  N=$(find "$R2DIR" -type f | wc -l)
  tar -C "$R2DIR" -cf - . | cifrar "$R"
  rm -rf "$R2DIR"
  subir "$R" "archivos=$N"
fi
rm -rf "$R2DIR"

if [ -n "$(ls -A "$EVIDENCIA" 2>/dev/null)" ]; then
  E="$DIR/denuncias-$SELLO.tar.gpg"
  tar -C "$EVIDENCIA" -cf - . | cifrar "$E"
  subir "$E"
fi

# En R2 lo borra la regla «borrar-30-dias» del bucket.
rclone delete "$REMOTE" --min-age 30d --quiet || true
estado "OK $(basename "$F.gpg") usuarios=$USERS"
