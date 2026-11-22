# shellcheck shell=bash
# Ejecuta en asus el guion que llega por la entrada estándar, con los argumentos dados. Lo cargan
# bin/deploy y bin/rollback, que sirven lanzados desde el Air o desde la propia asus.
# ControlPath=none: una conexión multiplexada abierta antes de entrar en el grupo docker no lo tiene.
# Desde asus, si este shell tampoco lo tiene (tmux arrancado antes), se entra por el Air, porque asus
# no se acepta ssh a sí misma. Los argumentos pasan por uno o dos shells remotos: solo palabras simples.
en_asus() {
  if [ -d ~/services/comunia/.git ]; then
    if docker ps -q >/dev/null 2>&1; then
      bash -s -- "$@"
    else
      ssh air ssh -o ControlPath=none asus bash -s -- "$@"
    fi
  else
    ssh -o ControlPath=none asus bash -s -- "$@"
  fi
}
