#!/usr/bin/env bash
# Vigilante del acceso público de COMUNIA (crontab de asus_2025, cada 5 min; decisión de Héctor, 29-oct-2026).
# El 29-oct, de 05:03 a 06:37 UTC, el nodo Tailscale «comunia» perdía cada ~30 s la conexión con el control y
# con DERP, y el relé de Funnel cortaba el TLS: por dentro del tailnet todo respondía, desde fuera nada.
# Reiniciar solo el contenedor ts lo arregló.
#  1. Prueba /salud por las IPs públicas del relé (DNS público: desde asus el nombre resuelve al tailnet y
#     un curl normal no pasa por Funnel).
#  2. Si fallan todas, suma un fallo; con 2 seguidos (unos 10 min) reinicia comunia-ts-1, como mucho una
#     vez cada 30 min. No toca web ni db.
# Registro en ~/.local/state/comunia-funnel/vigila.log. Quitarlo: borrar su línea del crontab.
set -uo pipefail

HOST=comunia.tail0be41e.ts.net
CONTENEDOR=comunia-ts-1
DIR=$HOME/.local/state/comunia-funnel
mkdir -p "$DIR"
LOG=$DIR/vigila.log
FALLOS=$DIR/fallos
ULTIMO_REINICIO=$DIR/ultimo-reinicio

registrar() { echo "$(date -u +%FT%TZ) $*" >> "$LOG"; }

ips=$(curl -s --max-time 10 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$HOST&type=A" |
      jq -r '.Answer[]? | select(.type == 1) | .data' 2>/dev/null)
# Si el DNS público no contesta, se prueba con las del 28-oct.
[ -n "$ips" ] || ips="199.38.181.54 209.177.145.137"

detalle=""
for ip in $ips; do
  codigo=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 --resolve "$HOST:443:$ip" "https://$HOST/salud")
  if [ "$codigo" = "200" ]; then
    [ -s "$FALLOS" ] && registrar "responde de nuevo por $ip"
    rm -f "$FALLOS"
    exit 0
  fi
  detalle="$detalle $ip=$codigo"
done

fallos=$(( $(cat "$FALLOS" 2>/dev/null || echo 0) + 1 ))
echo "$fallos" > "$FALLOS"
registrar "fallo $fallos:$detalle"
[ "$fallos" -ge 2 ] || exit 0

ahora=$(date +%s)
if [ $(( ahora - $(cat "$ULTIMO_REINICIO" 2>/dev/null || echo 0) )) -lt 1800 ]; then
  registrar "sin reiniciar: el último reinicio fue hace menos de 30 min"
  exit 0
fi
echo "$ahora" > "$ULTIMO_REINICIO"
if docker restart "$CONTENEDOR" > /dev/null 2>&1; then
  registrar "reiniciado $CONTENEDOR"
else
  registrar "no se pudo reiniciar $CONTENEDOR"
fi
