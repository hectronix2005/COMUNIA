#!/usr/bin/env bash
# Vuelve producción de COMUNIA (asus) a una versión anterior. Lo lanza bin/rollback (por ssh, con
# versiones.sh delante) o desplegar.sh cuando la sonda falla (--auto).
#   rollback.sh [--seco] [--auto] [--aceptar-base-nueva] [versión]
# Sin versión: la versión buena anterior a la que está en marcha. Hace: comprobar que la imagen
# comunia-web:<versión> existe → retaguearla como latest y arrancar web por el mismo compose del
# despliegue → sonda → avisar a la flota. NO restaura la base: si la base tiene migraciones que esa
# versión no conoce, lo dice y para (salida 3); restaurar la copia o seguir con --aceptar-base-nueva
# lo decide Héctor. Las migraciones con una línea «# rollback: compatible» no paran.
# Salidas: 0 hecho (o --seco sin pegas), 1 error, 3 para por la base.
set -euo pipefail
declare -F version_en_marcha >/dev/null || source "$(dirname "${BASH_SOURCE[0]}")/versiones.sh"
cd "$COMUNIA_DIR"

SECO=0 AUTO=0 ACEPTAR=0 OBJETIVO=
for a in "$@"; do
  case "$a" in
    --seco) SECO=1 ;;
    --auto) AUTO=1 ;;
    --aceptar-base-nueva) ACEPTAR=1 ;;
    v[0-9]*) OBJETIVO=$a ;;
    *) echo "argumento desconocido: $a" >&2; exit 1 ;;
  esac
done
[ "$SECO" = 1 ] || candado

git fetch --quiet --tags --force origin 2>/dev/null || aviso "no se pudieron traer las etiquetas de origin (sigo con las locales)"

ACTUAL=$(version_en_marcha)
BUENAS=$(versiones_buenas)
echo "en marcha: ${ACTUAL:-sin versión ($(docker inspect "$CONTENEDOR" --format '{{.Config.Image}} {{.Image}}' 2>/dev/null | cut -c1-40))}"
echo "versiones con imagen y etiqueta: $(echo "$BUENAS" | xargs)"

if [ -z "$OBJETIVO" ]; then
  if [ -n "$ACTUAL" ]; then
    OBJETIVO=$( { echo "$BUENAS"; echo "$ACTUAL"; } | grep . | sort -rV | uniq | grep -A1 -x -F "$ACTUAL" | sed -n 2p || true)
  else
    OBJETIVO=$(echo "$BUENAS" | sed -n 1p)
  fi
  [ -n "$OBJETIVO" ] || { echo "no hay una versión anterior con imagen a la que volver" >&2; exit 1; }
fi

docker image inspect "$IMAGEN:$OBJETIVO" >/dev/null 2>&1 ||
  { echo "no está la imagen $IMAGEN:$OBJETIVO en asus (se guardan las $CONSERVAR últimas)" >&2; exit 1; }
if [ "$OBJETIVO" = "$ACTUAL" ]; then
  echo "$OBJETIVO ya está en marcha: nada que hacer"
  exit 0
fi
COMMIT=$(git rev-parse -q --verify "refs/tags/$OBJETIVO^{commit}" || true)

# La base: migraciones aplicadas que conoce el código en marcha y no conoce la versión objetivo. (Se
# cruza con el código en marcha porque schema_migrations guarda versiones huérfanas, como «1».)
BASE_NUEVA= NUEVAS=
if [ -n "$COMMIT" ]; then
  # shellcheck disable=SC2015  # sin etiqueta de la versión en marcha, el checkout (que puede traer código aún sin
  # desplegar: sus marcas de compatibles y sus vueltas contarían de más)
  REF=$( [ -n "$ACTUAL" ] && git rev-parse -q --verify "refs/tags/$ACTUAL^{commit}" || git rev-parse HEAD)
  EN_BASE=$(migraciones_en_base)   # si psql falla, set -e para aquí en vez de dar una lista vacía
  NUEVAS=$(comm -13 <(migraciones_de "$COMMIT") <(comm -12 <(echo "$EN_BASE") <(migraciones_de "$REF")))
  # Las que se declaran compatibles («# rollback: compatible») no paran la vuelta atrás.
  COMPATIBLES=$(comm -12 <(echo "$NUEVAS" | sed '/^$/d') <(migraciones_compatibles "$REF") | xargs)
  BASE_NUEVA=$(comm -23 <(echo "$NUEVAS" | sed '/^$/d') <(migraciones_compatibles "$REF") | xargs)
  [ -z "$COMPATIBLES" ] || echo "migraciones nuevas compatibles con $OBJETIVO, no paran: $COMPATIBLES"
else
  BASE_NUEVA="(sin etiqueta de git: no se puede comprobar)"
  echo "sin etiqueta de $OBJETIVO: no se ejecutan las vueltas de config/deploy/asus/vuelta" >&2
fi

echo "objetivo: $OBJETIVO (${COMMIT:-sin commit}) con la imagen $IMAGEN:$OBJETIVO"
if [ -n "$BASE_NUEVA" ] && [ "$ACEPTAR" = 0 ]; then
  # La copia hecha justo antes de arrancar la versión en marcha.
  COPIA="$COPIAS_VERSION/comunia-$ACTUAL.dump"
  [ -n "$ACTUAL" ] && [ -f "$COPIA" ] || COPIA=
  MSG="La base tiene migraciones que $OBJETIVO no conoce: $BASE_NUEVA. No restauro la base: lo decide Héctor (restaurar la copia ${COPIA:-de backup.sh} o repetir con --aceptar-base-nueva si el código de $OBJETIVO aguanta la base nueva)."
  echo "$MSG" >&2
  if [ "$SECO" = 0 ]; then
    avisar "COMUNIA: rollback a $OBJETIVO parado por la base" "En marcha: ${ACTUAL:-sin versión}. $MSG"
  fi
  exit 3
fi

if [ "$SECO" = 1 ]; then
  echo "--seco: retaguearía $IMAGEN:$OBJETIVO como latest, arrancaría web con «${COMPOSE[*]} up -d --no-build web», esperaría $SONDA_LOCAL y avisaría a la flota. No he cambiado nada (solo he traído las etiquetas de origin)."
  exit 0
fi

echo "rollback: ${ACTUAL:-sin versión} → $OBJETIVO"
# Lo que pida cada migración nueva para volver atrás: config/deploy/asus/vuelta/<versión>.sql del código en marcha
# (REF), en una transacción y con web parado, para que nada escriba entre el ajuste y el cambio de imagen. Si falla,
# web vuelve a arrancar con la versión en marcha, se avisa y se para.
VUELTAS=
for v in $NUEVAS; do
  git cat-file -e "$REF:config/deploy/asus/vuelta/$v.sql" 2>/dev/null && VUELTAS="$VUELTAS $v"
done
if [ -n "$VUELTAS" ]; then
  "${COMPOSE[@]}" stop web
  for v in $VUELTAS; do
    f="config/deploy/asus/vuelta/$v.sql"
    echo "vuelta de $v: $f"
    if ! git show "$REF:$f" | docker exec -i comunia-db-1 psql -U comunia -d comunia_production -v ON_ERROR_STOP=1 -1 -q; then
      "${COMPOSE[@]}" start web || true
      avisar "COMUNIA: rollback a $OBJETIVO parado" "Falló $f antes de cambiar de imagen: sigue ${ACTUAL:-sin versión} (web arrancado otra vez). Hace falta mirarlo a mano."
      exit 1
    fi
  done
fi
docker tag "$IMAGEN:$OBJETIVO" "$IMAGEN:latest"
"${COMPOSE[@]}" up -d --no-build web
MOTIVO=$([ "$AUTO" = 1 ] && echo "automático: la sonda falló tras desplegar ${ACTUAL:-?}" || echo "manual")
if sonda_local; then
  echo "$OBJETIVO ${COMMIT:-?}" > "$ESTADO_VERSION"
  avisar "COMUNIA: rollback a $OBJETIVO hecho" "Rollback $MOTIVO. Antes: ${ACTUAL:-sin versión}; ahora: $OBJETIVO; sonda local en verde."
  exit 0
fi
avisar "COMUNIA: rollback a $OBJETIVO FALLIDO" "Rollback $MOTIVO. La sonda local sigue en rojo tras volver a $OBJETIVO. Hace falta mirarlo a mano."
exit 1
