#!/usr/bin/env bash
# Claves de los pases anónimos de DENUNCIAPP (crontab de asus_2025, a diario).
# Una RSA de 2048 bits (e=65537) por mes UTC, la misma para todos los miembros:
# ~/.config/comunia-pases/AAAA-MM.pem (carpeta 700, ficheros 600). El contenedor
# web la monta en solo lectura (compose.yml); la app firma con la del mes en curso
# y publica esa y la anterior. Este guion deja creada la del mes siguiente antes de
# que empiece y borra las que ya no se publican. Nunca van a git ni a las copias de
# Drive (backup.sh solo vuelca Postgres). Si se pierden, solo se pierden los pases
# de ese mes: se generan otras.
set -euo pipefail
export PATH="/usr/bin:/bin"
DIR="$HOME/.config/comunia-pases"
LOG="$HOME/services/comunia-pases.log"

umask 077
mkdir -p "$DIR"
chmod 700 "$DIR"

for mes in "$(date -u +%Y-%m)" "$(date -u -d "$(date -u +%Y-%m-15) +1 month" +%Y-%m)"; do
  f="$DIR/$mes.pem"
  [ -s "$f" ] && continue
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:65537 \
    -out "$f.tmp" 2>/dev/null
  mv "$f.tmp" "$f"
  echo "$(date '+%F %T') clave creada: $mes" >> "$LOG"
done

anterior="$(date -u -d "$(date -u +%Y-%m-15) -1 month" +%Y-%m)"
for f in "$DIR"/*.pem; do
  mes="$(basename "$f" .pem)"
  if [[ "$mes" < "$anterior" ]]; then
    rm -f "$f"
    echo "$(date '+%F %T') clave borrada (ya no se publica): $mes" >> "$LOG"
  fi
done
