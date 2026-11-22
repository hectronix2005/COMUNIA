# COMUNIA

Rails 8 + Postgres. Producción en asus (WSL) con Docker compose: `config/deploy/asus/compose.yml`
(servicios `db`, `web` y `ts`, el Funnel en https://comunia.tail0be41e.ts.net). Se despliega a mano con
`bin/deploy` (desde el Air o desde asus): unir a `main` NO despliega. Sonda: `/salud` (`/up` y además la
base); la vigila también `.github/workflows/disponibilidad.yml`. Las migraciones corren al arrancar
(`bin/docker-entrypoint` → `db:prepare`). Copia diaria cifrada de la base y los archivos:
`config/deploy/asus/backup.sh` (cron de asus, 3:45, a R2 y Drive).

## Versiones y rollback

- **Etiquetas.** Cada `bin/deploy` con la sonda en verde crea la etiqueta anotada `vAAAA.MM.DD-N`
  (N = 1, 2… en el día) sobre el commit desplegado, la sube y crea la Release de GitHub
  (`gh release create --generate-notes`). Si eso falla, el despliegue no falla: solo avisa.
  La versión en marcha queda en `~/services/comunia-version` de asus.
- **Imágenes.** En el docker de asus: `comunia-web:<versión>` por cada despliegue (y `comunia-web:latest`
  = la que está en marcha). Se guardan las **5 últimas** versiones; `docker images comunia-web`.
- **Copia antes de migrar.** Antes de arrancar cada versión, `pg_dump -Fc` en
  `~/backups/comunia-versiones/comunia-<versión>.dump` de asus (fuera del repo, 700; las 5 últimas). Si la
  copia falla, no se despliega.
- **`bin/rollback --seco`**: dice a qué versión volvería y comprueba que su imagen está, sin tocar nada.
- **`bin/rollback [versión]`**: sin argumento, la versión anterior a la que está en marcha. Retaguea su
  imagen como `latest`, arranca `web` con el mismo compose, espera la sonda y avisa (carta a Ultron por
  `bandeja.sh`; si falla, push con `wt_push.py`).
- **Automático.** Si la sonda local falla tras un despliegue, `bin/deploy` llama una sola vez al rollback a
  la versión anterior y termina con error.
- **Lo que NO hace: restaurar la base.** Si la base tiene migraciones que la versión objetivo no conoce, el
  rollback lo dice y para (salida 3). Restaurar la copia (`pg_restore`, ver `backup.sh`) o seguir con
  `bin/rollback --aceptar-base-nueva <versión>` lo decide Héctor.
- La lógica está en `config/deploy/asus/{desplegar,rollback,versiones}.sh`.
