#!/usr/bin/env bash
# shellcheck disable=SC2174  # mkdir -m solo hace falta en la última carpeta
# Despliegue de COMUNIA en asus. Lo lanza bin/deploy después de dejar ~/services/comunia en origin/main;
# recibe el commit que había antes (para dar versión a la que está en marcha si aún no la tiene).
#  0. Si lo que corre ya es este commit (misma versión y sonda en verde), termina sin hacer nada.
#  1. Construye la imagen y la etiqueta comunia-web:<versión> (vAAAA.MM.DD-N).
#  2. Copia de la base (pg_dump -Fc) en ~/backups/comunia-versiones/comunia-<versión>.dump ANTES de
#     arrancar: las migraciones corren al arrancar (bin/docker-entrypoint → db:prepare). Guarda las 5 últimas.
#  3. Arranca la versión y espera la sonda local (/salud).
#  4. Sonda en rojo → bin/rollback automático a la versión anterior (una sola vez) y termina con error.
#  5. Sonda en verde → etiqueta anotada de git + Release de GitHub (si falla, solo avisa), borra las
#     imágenes de versión más allá de las 5 últimas y comprueba la sonda pública.
set -euo pipefail
cd "${COMUNIA_DIR:-$HOME/services/comunia}"
source config/deploy/asus/versiones.sh
candado

ANTES=${1:-}
COMMIT=$(git rev-parse HEAD)
mkdir -p -m 700 "$DENUNCIAS_DIR" "$STORAGE_DIR"
git fetch --quiet --tags --force origin || aviso "no se pudieron traer las etiquetas de origin"

# Versión en marcha. Si su imagen aún no tiene versión (primer despliegue con versionado), se le da una,
# con su etiqueta de git en el commit que había antes, para que el rollback tenga adónde volver.
ANTERIOR=$(version_en_marcha)
if [ -z "$ANTERIOR" ] && [ -n "$ANTES" ] && docker inspect "$CONTENEDOR" >/dev/null 2>&1; then
  ANTERIOR=$(siguiente_version)
  docker tag "$(docker inspect "$CONTENEDOR" --format '{{.Image}}')" "$IMAGEN:$ANTERIOR"
  # shellcheck disable=SC2015  # el aviso sale si falla la etiqueta o la subida
  git tag -a "$ANTERIOR" "$ANTES" -m "COMUNIA $ANTERIOR (versión que ya estaba en marcha al empezar el versionado)" &&
    git push --quiet origin "refs/tags/$ANTERIOR" ||
    aviso "no se pudo etiquetar en git la versión en marcha $ANTERIOR"
  echo "versión en marcha sin número: queda como $ANTERIOR ($ANTES)"
fi

# Nada que desplegar: lo que corre ya es este commit, con su versión y la sonda en verde. Sin esto, un
# bin/deploy repetido reconstruía, copiaba la base, recreaba el contenedor y sacaba otra versión del mismo
# commit (v2026.11.22-3 = -2, 22-nov-2026). Para reconstruir igualmente: COMUNIA_FORZAR=1 (en asus).
if [ "${COMUNIA_FORZAR:-0}" != 1 ] && [ -n "$ANTERIOR" ] && [ "$ANTES" = "$COMMIT" ] &&
   [ "$(cat "$ESTADO_VERSION" 2>/dev/null)" = "$ANTERIOR $COMMIT" ] && sonda_local >/dev/null 2>&1; then
  echo "nada que desplegar: $ANTERIOR ya sirve ${COMMIT:0:7} (COMUNIA_FORZAR=1 para reconstruir)"
  exit 0
fi

EN_MARCHA_ID=$(docker inspect "$CONTENEDOR" --format '{{.Image}}' 2>/dev/null || true)
VERSION=$(siguiente_version)
echo "desplegando $VERSION ($COMMIT; anterior: ${ANTERIOR:-ninguna})"
"${COMPOSE[@]}" build web
docker tag "$IMAGEN:latest" "$IMAGEN:$VERSION"

# Copia antes de migrar. Si falla, no se arranca nada: sigue en marcha la versión anterior.
mkdir -p -m 700 "$COPIAS_VERSION"
COPIA="$COPIAS_VERSION/comunia-$VERSION.dump"
# latest vuelve a la imagen en marcha si no se llega a arrancar la nueva (un compose up a mano no la cogería).
no_se_despliega() {
  rm -f "$COPIA.tmp"
  [ -z "$EN_MARCHA_ID" ] || docker tag "$EN_MARCHA_ID" "$IMAGEN:latest" || true
  echo "$1: no se despliega; sigue en marcha ${ANTERIOR:-la versión anterior}" >&2
  exit 1
}
(umask 077; docker exec comunia-db-1 pg_dump -Fc -U comunia comunia_production > "$COPIA.tmp") ||
  no_se_despliega "falló la copia de la base (pg_dump)"
docker exec -i comunia-db-1 pg_restore --list < "$COPIA.tmp" > /dev/null ||
  no_se_despliega "la copia de la base no pasa pg_restore --list"
mv "$COPIA.tmp" "$COPIA"
echo "copia de la base: $COPIA ($(du -h "$COPIA" | cut -f1))"
# shellcheck disable=SC2012  # nombres propios, sin espacios
ls -1t "$COPIAS_VERSION"/comunia-v*.dump 2>/dev/null | tail -n +$((CONSERVAR + 1)) | xargs -r rm -f

if ! "${COMPOSE[@]}" up -d --no-build || ! sonda_local; then
  if [ -n "$ANTERIOR" ] && [ "$ANTERIOR" != "$VERSION" ]; then
    echo "la sonda falla con $VERSION: rollback automático a $ANTERIOR"
    bash config/deploy/asus/rollback.sh --auto "$ANTERIOR" || true
  else
    avisar "COMUNIA: falló el despliegue $VERSION" "La sonda local no responde y no hay versión anterior a la que volver. Copia de la base: $COPIA."
  fi
  exit 1
fi

echo "$VERSION $COMMIT" > "$ESTADO_VERSION"

# Etiqueta y Release: si fallan, el despliegue sigue siendo bueno.
if git tag -a "$VERSION" "$COMMIT" -m "COMUNIA $VERSION (desplegada en asus el $(date '+%F %T %z'))" &&
   git push --quiet origin "refs/tags/$VERSION"; then
  if command -v gh >/dev/null 2>&1; then
    gh release create "$VERSION" --verify-tag --generate-notes --title "COMUNIA $VERSION" >/dev/null ||
      aviso "no se pudo crear la Release de $VERSION (la etiqueta sí está)"
  fi
else
  aviso "no se pudo crear o subir la etiqueta $VERSION"
fi

# Imágenes: se quedan las 5 últimas versiones buenas, la que está en marcha y la anterior; las de
# despliegues fallidos no ocupan hueco. Luego, las colgadas.
GUARDAR=" $(versiones_buenas | head -n "$CONSERVAR" | xargs) $(version_en_marcha) $ANTERIOR "
versiones_imagen | while read -r v; do
  case "$GUARDAR" in *" $v "*) continue ;; esac
  docker rmi "$IMAGEN:$v" >/dev/null || aviso "no se pudo borrar $IMAGEN:$v"
done
docker image prune -f >/dev/null || aviso "no se pudieron limpiar las imágenes colgadas"

echo "desplegada $VERSION"
sonda_publica || { echo "la app responde en local pero no por Funnel (vigila-funnel.sh lo reinicia): no se revierte" >&2; exit 1; }
