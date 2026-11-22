# shellcheck shell=bash disable=SC2034  # variables para quien carga este fichero
# Funciones comunes de desplegar.sh y rollback.sh (producción de COMUNIA en asus). Se cargan con
# `source`; bin/rollback las manda por ssh delante de rollback.sh, así que no deben depender de su ruta.
#
# Versiones: vAAAA.MM.DD-N (N = 1, 2… en el día). Cada versión es a la vez una etiqueta anotada de git
# (solo se crea con la sonda en verde) y una imagen comunia-web:<versión> en el docker de asus.
# comunia-web:latest es siempre la que está en marcha (la retaguea también el rollback).
# Una versión «buena» = tiene etiqueta de git y su imagen sigue en asus.

COMUNIA_DIR=${COMUNIA_DIR:-$HOME/services/comunia}
IMAGEN=comunia-web
CONTENEDOR=comunia-web-1
COPIAS_VERSION=${COPIAS_VERSION:-$HOME/backups/comunia-versiones}  # pg_dump antes de cada despliegue
ESTADO_VERSION=$HOME/services/comunia-version                      # «<versión> <commit>» en marcha
CANDADO=$HOME/services/comunia-despliegue.lock
CONSERVAR=5
SONDA_LOCAL=http://127.0.0.1:3480/salud            # /up y además la base (SaludController)
SONDA_PUBLICA=https://comunia.tail0be41e.ts.net/salud

export SECRETS_DIR=$HOME/services/comunia-secrets
export DENUNCIAS_DIR=$HOME/services/denuncias-evidencia
export STORAGE_DIR=$HOME/services/comunia-storage
COMPOSE=(docker compose -f "$COMUNIA_DIR/config/deploy/asus/compose.yml")

aviso() { echo "AVISO: $*" >&2; }

# Toma el candado de despliegue (fd 8) salvo que ya lo tenga quien nos llama (rollback automático).
candado() {
  [ "${COMUNIA_CANDADO:-}" = 1 ] && return 0
  exec 8>"$CANDADO"
  flock -n 8 || { echo "ya hay un despliegue o rollback en curso ($CANDADO)" >&2; exit 1; }
  export COMUNIA_CANDADO=1
}

# Etiquetas de imagen comunia-web:v* (sin el prefijo), de la más nueva a la más vieja.
versiones_imagen() {
  docker images "$IMAGEN" --format '{{.Tag}}' | grep -E '^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]+$' | sort -rV || true
}

# Versiones buenas (etiqueta de git + imagen), de la más nueva a la más vieja.
versiones_buenas() {
  local v
  for v in $(versiones_imagen); do
    git -C "$COMUNIA_DIR" rev-parse -q --verify "refs/tags/$v" >/dev/null && echo "$v"
  done
  return 0
}

# Versión de la imagen con que corre el contenedor web ("" si no tiene etiqueta de versión).
version_en_marcha() {
  local id v
  id=$(docker inspect "$CONTENEDOR" --format '{{.Image}}' 2>/dev/null) || return 0
  for v in $(versiones_imagen); do
    [ "$(docker image inspect "$IMAGEN:$v" --format '{{.Id}}' 2>/dev/null)" = "$id" ] && { echo "$v"; return 0; }
  done
  return 0
}

# Siguiente versión del día: mira las etiquetas de git (locales y de origin) y las imágenes, para no
# repetir un número aunque una etiqueta no llegara a subirse.
siguiente_version() {
  local hoy n max=0
  hoy=v$(date +%Y.%m.%d)
  for n in $( { git -C "$COMUNIA_DIR" tag -l "$hoy-*"; versiones_imagen; } | grep -E "^$hoy-[0-9]+$" | sed "s/^$hoy-//"); do
    [ "$n" -gt "$max" ] && max=$n
  done
  echo "$hoy-$((max + 1))"
}

# Sonda local: 200 en /salud antes de ~2 min (arranque de Rails + migraciones).
sonda_local() {
  local code=000
  for _ in $(seq 1 12); do
    code=$(curl -sS -m 10 -o /dev/null -w '%{http_code}' -H 'X-Forwarded-Proto: https' "$SONDA_LOCAL" 2>/dev/null || true)
    [ "$code" = 200 ] && { echo "sonda local: 200"; return 0; }
    sleep 10
  done
  echo "sonda local: $code" >&2
  return 1
}

# Sonda pública (Funnel). Si falla con la local en verde, el fallo es del relé, no de la versión.
sonda_publica() {
  local code=000
  for _ in 1 2 3 4 5 6; do
    code=$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "$SONDA_PUBLICA" 2>/dev/null || true)
    [ "$code" = 200 ] && { echo "sonda pública: 200"; return 0; }
    sleep 10
  done
  echo "sonda pública: $code" >&2
  return 1
}

# Versiones de las migraciones que conoce un commit (prefijo numérico de db/migrate/*.rb).
migraciones_de() {
  git -C "$COMUNIA_DIR" ls-tree --name-only "$1" db/migrate/ | sed -nE 's#^db/migrate/([0-9]+)_.*\.rb$#\1#p' | sort
}

# Migraciones aplicadas en la base de producción (solo lectura).
migraciones_en_base() {
  docker exec comunia-db-1 psql -U comunia -d comunia_production -Atc 'select version from schema_migrations' | sort
}

# Aviso a la flota: carta a Ultron y, si no se pudo dejar, push al móvil. Nunca hace fallar a quien llama.
avisar() {
  local titulo="$1" detalle="$2" bandeja=$HOME/RubymineProjects/Ultron/monitor/bandeja.sh
  echo "$titulo — $detalle"
  if [ -f "$bandeja" ] &&
     printf 'Asunto: %s\n\n%s\n\n(Lo escribió el despliegue de COMUNIA en %s.)\n' "$titulo" "$detalle" "$(hostname -s)" |
       timeout 90 bash "$bandeja" dejar-en air Ultron - >/dev/null 2>&1; then
    return 0
  fi
  timeout 30 ssh -n -o BatchMode=yes -o ConnectTimeout=10 air \
    "python3 ~/RubymineProjects/Ultron/web/wt_push.py --tag rollback $(printf '%q' "$titulo") $(printf '%q' "$detalle")" \
    >/dev/null 2>&1 || aviso "no se pudo avisar a la flota (ni carta ni push)"
  return 0
}
