# NOTAS — COMUNIA

Plan vivo. Piloto automático del 24-oct-2026 21:35 al 25-oct-2026 09:35 (hora Colombia), por
orden de Héctor (carta de Tmux): llevar COMUNIA a una **red social de comunidades certificadas**.

Estados: ✅ hecho y verificado · 🔄 en curso · ⏳ pendiente · ⛔ bloqueado por Héctor

## Decisiones de diseño (tomadas en piloto, con la opción recomendada)

- **Módulo `Red`** dentro de COMUNIA, con tablas `red_*`, rutas bajo `/red` y su propio layout,
  pensado para móvil. Reutiliza `User` (Devise, `:lockable`), `Notificacion`/push y Bootstrap.
- **Cuentas solo de la red** (`users.solo_red`): sin logia. Un filtro global las encierra en `/red`
  (no ven nada del módulo de logias). Entran con su correo en `/red/entrar` (Devise). El registro
  público lleva Turnstile, límite de intentos y consentimiento de la Ley 1581.
- **Las logias ya existentes** pueden certificarse como comunidad (vínculo «logia»): sus miembros
  activos quedan avalados por el registro oficial de la logia.
- **Privacidad entre comunidades** (innegociable):
  - Nadie más que la persona y la plataforma ve a qué comunidades pertenece.
  - Hacia fuera solo se muestra una **ficha pública** que se lee de una foto fija
    (`red_confianzas`): nivel 0–4, número de comunidades y una banda del total de miembros. Nunca
    nombres ni ids de comunidades.
  - Los ids públicos son tokens aleatorios.
  - Lo oculto responde igual que lo inexistente: mismo 404, mismas consultas.
  - El orden de los resultados usa solo datos públicos (nivel, fecha).
  - La foto de confianza se recalcula en lote una vez al día, no en el momento del cambio.
- **Confianza** (`Red::Confianza`): aporte por comunidad = log10(n)/4, con tope 1. Se multiplica por:
  - la solidez de la comunidad: certificada, ≥5 miembros, rampa de 180 días;
  - la antigüedad de la membresía: rampa de 30 días.
  - Además:
    - los avales en anillo (A avala a B y B avala a A) valen la cuarta parte;
    - dos comunidades que comparten más del 80 % de sus miembros cuentan como una sola;
    - las comunidades se ordenan de mayor a menor aporte y cada una vale 0,7 veces la anterior;
    - cada sanción de moderación divide entre dos.
- **Visibilidad** de perfil y publicación:
  - `mis_comunidades`: solo mi comunidad.
  - `elegidas`: las comunidades concretas que yo elija.
  - `publico`: todas las comunidades y la búsqueda sin cuenta, con mi nivel de confianza.
- **Contacto intermediado**: conversación dentro de COMUNIA. Quien busca sin cuenta deja un mensaje
  con captcha y su propio medio de contacto, cifrado. El teléfono o el correo de la persona solo
  salen si ella pulsa «compartir mi contacto».

## Plan (por valor)

1. ✅ Estudio de lo existente y decisión de qué se reutiliza (hecho en el diseño de arriba)
2. ✅ Modelo de datos `red_*`, cuentas `solo_red` encerradas en `/red`, pruebas de encierro, fórmula y alcance (test/red: 23 pruebas)
3. ✅ Comunidades: solicitud, certificación por la plataforma, membresías con evidencia,
   verificadores, revisión, revocación, renovación, certificar una logia (test/red/comunidades_test.rb)
4. ✅ Perfiles (hoja de vida incluida), publicaciones necesito/ofrezco con alcance, topes, cuarentena
   y filtro de estafas, exportar y borrar mis datos (test/red/perfiles_publicaciones_test.rb)
5. ✅ Fórmula de confianza y antifraude: cuarentena, topes, anillos, duplicados, filtros de estafa,
   lote diario a las 4 a. m. (Red::MantenimientoDiarioJob), alertas de comunidades infladas
6. ✅ Búsqueda pública sin cuenta (HTML y JSON con lista blanca), filtros y categorías, tope de 25
   páginas. Pruebas de extracción de la privacidad (test/red/privacidad_test.rb, 11 ataques)
7. ✅ Mensajería intermediada (el contacto solo sale si se comparte), contacto sin cuenta con
   captcha, consentimiento y medio cifrado, bloqueo, reseñas verificables (tras conversación real de
   los dos y un día), reportes (uno por persona o IP con HMAC; a los 3, a revisión y aviso a
   moderación), avisos con campana, tope diario de conversaciones nuevas (20; 5 en cuarentena)
   (test/red/mensajeria_test.rb, 14 pruebas)
8. ✅ Páginas «Cómo funciona» (fórmula explicada) y «Privacidad» (Ley 1581, borrador), semillas
   ficticias (`bin/rails red:demo`, correos @ejemplo.invalid, repetible, prohibida en producción),
   sección en el README, repaso de accesibilidad (encabezados, etiquetas, foco, menú sin cortes) y
   prueba en navegador (Chromium sin ventana, 390 px y 1280 px) (test/red/paginas_test.rb)

## Resultado del piloto (24-oct, 22:45)

Hecho y verificado:

- Suite completa: 168 pruebas en verde (81 de la red), brakeman sin avisos, bundle-audit limpio.
- En navegador contra un servidor local (puerto 3099, datos de demostración), en móvil y escritorio:
  portada, búsqueda (publicaciones y personas), cómo funciona, privacidad, catálogo de comunidades,
  publicación, contacto sin cuenta, entrar, avisos con campana, mensajes, compartir contacto, mi
  perfil, mis publicaciones, publicar, mis comunidades, comunidad, gestión y directorio. Todas con
  200, sin errores de consola y sin scroll horizontal.

No hecho o no comprobado:

- La pantalla de moderación no se recorrió en navegador; la cubren las pruebas.
- Turnstile real y el envío de correo no se pudieron probar: no hay claves ni servicio.
- Las notificaciones push de la red usan el sistema de COMUNIA y no se probaron en un móvil real.

## Despliegue (24-oct, 22:55, por decisión de Héctor)

- Copia previa en Drive: `comunia-20261024-2245.dump.gpg` (49 usuarios).
- `git push` de los 8 commits y `bin/deploy`: imagen nueva, migración 20261024220000 aplicada, tarea
  `red_mantenimiento` (4 a. m.) registrada en Solid Queue. `/up` responde 200.
- Comprobado en https://comunia.tail0be41e.ts.net: `/login`, `/red`, búsqueda (HTML y JSON),
  cómo funciona, privacidad, comunidades, entrar y registro dan 200; lo privado redirige a
  `/red/entrar`. Sin Turnstile, el registro se ve pero no crea cuentas («Hoy no podemos crear
  cuentas nuevas»), y el contacto sin cuenta tampoco funciona.
- 24-oct, 23:05: primera comunidad, **Logia Propagadores de la Luz N1** (la única con miembros
  activos), certificada por la cuenta de plataforma con `Red::CertificarLogia`: 28 membresías
  verificadas, 0 perfiles todavía. Las demás logias tienen 0 activos.
- 24-oct, 23:20, desplegado 49c1b26 (por decisión de Héctor):
  - 1fedecf: la tarea diaria vuelve a sincronizar las logias certificadas (altas, bajas y
    renovación). Probado en producción: la logia sigue con 28.
  - Enlace «Red» en el menú de COMUNIA (escritorio y móvil) y «Volver a COMUNIA» en el pie de la
    red, solo para cuentas con logia. Recorrido en navegador (1280 y 390 px).
  - La red nunca se sirve bajo `/t/<slug>`: un enlace copiado dentro del tenant habría delatado la
    organización de quien lo comparte. GET → 301 a `/red/...`; escrituras → 404. Comprobado en
    producción.

### Push y PWA arreglados (24-oct, 23:35, c49ce8e, por decisión de Héctor)

- Antes, las notificaciones push de COMUNIA nunca habían funcionado en producción (0 suscripciones):
  `/service-worker` daba 422 por la protección CSRF de Rails, el manifiesto salía con `&quot;` y
  el `scope` de la raíz era `"//"`.
- Ahora: service worker sin CSRF (es estático), manifiesto sin escapar, scope correcto y nonce en
  el script. Probado en local de punta a punta (registro, suscripción guardada, envío aceptado por
  FCM con 201) y en producción (`/service-worker` 200 JavaScript, manifiesto JSON válido).
- Desde ahora, COMUNIA pide permiso de notificaciones una vez por sesión, y a quien lo acepta le
  llegan los push (cumpleaños, avisos, red…). Las suscripciones empezarán a aparecer cuando los
  usuarios entren.

## Revisión del 25-oct (5a5d156, desplegado)

- 32 adjuntos del servicio «local» (22 anuncios, 7 pagos, otros soportes) no se abrían: en el
  contenedor no estaban. Se recuperaron de la carpeta `storage/` de desarrollo (los 32 con su MD5),
  se copiaron a `~/services/comunia-storage`, montado en /rails/storage, y entran en la copia diaria
  (`archivos-*.tar.gpg`). Verificado: 32 de 32 en producción y la copia subió a Drive.
- Devise `paranoid` y correos con `deliver_later`: «Olvidé mi contraseña» responde igual con o sin
  cuenta y ya no depende del SMTP (antes iba a localhost:25). Verificado: 303 a /login.
- `X-Robots-Tag: noindex` en perfiles y hojas de vida. Las publicaciones públicas siguen indexables
  (decide Héctor).
- `red_mantenimiento` corrió a las 4:00 del 25-oct sin fallos.
- Moderación revisada en el navegador (390 px) y desplegada (7e6ab11): certificar una comunidad o
  una logia pide confirmación, los estados se leen bien, los motivos repetidos se agrupan y las
  secciones vacías dicen «Nada pendiente». Con datos de prueba en local, que se borraron después.
- Publicaciones públicas y búsqueda con noindex (00e7072, desplegado a petición de Héctor).

## Seguridad e invitaciones (25-oct)

- ✅ **El login enseñaba usuarios y contraseñas de demostración** (279a34d, desplegado). Se cambiaron
  las 7 contraseñas publicadas en producción; ninguna cuenta acepta ya las viejas. No hay registro
  anterior al arranque del contenedor para saber si alguien las usó.
- ✅ **Un admin podía abrir y editar miembros de otra logia** cambiando el id (462764c,
  desplegado). Ahora da 404.
- ✅ **Revisión de los 40 controladores** (445c0ab..57ad3f8, desplegado el 25-oct; en producción la
  migración igualó los roles: 0 desincronizados):
  - Cambiar `/t/<slug>` en la URL enseñaba el directorio, el chat y el calendario de otra
    organización. Ahora lleva al dashboard propio.
  - Un miembro abría o tocaba por id las publicaciones, encuestas, fichas del directorio, eventos,
    anuncios, libros, mensajes y familiares de otra organización. Ahora da 404, igual que lo
    inexistente.
  - Un admin_logia abría cobros, recibos, conceptos, tarifas, cortes, cargos, cambios de estado y
    roles de otras logias, y podía poner un `logia_id` ajeno al crear usuarios o roles. Arreglado.
  - La moderación (borrar, fijar, cerrar) miraba el enum `rol` y valía en cualquier logia; ahora
    mira `rol_ref` y solo vale en las logias que el admin gestiona.
  - Los familiares de un miembro solo los ve él o el hospitalario. El indicador de «escribiendo»
    solo va a canales propios.
  - La confirmación de asistencia daba siempre 404 (leía un parámetro que no llega). Arreglada.
  - Prueba nueva `test/integration/alcance_tenants_test.rb` (falla sin el arreglo). 192 pruebas en
    verde; brakeman y bundle-audit sin avisos.
  - El enum `rol` no coincidía con `rol_ref` en 5 usuarios de producción: «Cambiar rol» en la ficha
    solo cambiaba `rol_ref`. Ahora el modelo copia el enum de `rol_ref` al guardar, y la migración
    20261025200000 iguala los 5 al desplegar (`db:prepare`). Nadie gana ni pierde acceso: los
    permisos ya salían de `rol_ref`.
  - Hospitalía aceptaba un miembro de otra organización en un recaudo o un gasto, y la lista
    enseñaba su nombre. Ahora lo rechaza; en producción no había ninguno.
  - Los periodos de cobro eran globales: se arreglaron el 25-oct (ver «Periodos de cobro por
    organización»).
- ✅ **Invitaciones por enlace** (c80f1f4, desplegado el 25-oct con su migración; en producción
  cargan la ficha y la lista, y las rutas de la gema dan 404):
  - El admin pulsa «Invitar» en la ficha. Sale un enlace de un solo uso que caduca a los 7 días,
    para mandar por WhatsApp o copiar. No se envía ningún correo.
  - El miembro elige su contraseña (mínimo 10) y llega a `/bienvenida`, donde activa los avisos e
    instala la app.
  - La lista de miembros muestra quién está invitado, quién entró y quién nunca entró, con un
    resumen de los activos.
  - Solo invita quien puede editar al miembro, nunca a sí mismo. A un admin solo lo invita el
    superadmin.
  - Las rutas propias de devise_invitable están desactivadas: dejaban invitar a cualquiera y borrar
    la cuenta.
  - Límite de 20 intentos por hora y por IP.
  - Revisado en el navegador a 390 px: ficha, enlace, aceptar, bienvenida, enlace reutilizado y
    lista.
  - 183 pruebas en verde; brakeman y bundle-audit sin avisos.

## Prueba de restauración de la copia (25-oct)

- ✅ Se bajó de Drive la copia de las 07:28 (`comunia-20261025-0728.dump.gpg` y
  `archivos-20261025-0728.tar.gpg`), se descifró con la clave de asus y se restauró en un Postgres 17
  desechable, aparte de producción:
  - `pg_restore` sin errores; 79 tablas, y usuarios (49), miembros (41), logias (6), cobros (662),
    pagos (625), eventos (53), mensajes (24) y blobs (34) iguales que en producción.
  - Los 32 archivos del servicio `local` están en el tar y su MD5 coincide con el de la base.
  - Sobre la copia restaurada corren las migraciones de hoy (invitaciones y roles) sin error.
  - Se borraron el contenedor y los descifrados.
- Lo que la copia no trae: los 2 blobs del servicio `cloudflare` (R2), que viven solo en R2, y lo
  que ocurra después de la última copia (la diaria es a las 3:45).
- La base de producción guarda también las tablas de Solid Queue y Solid Cable y la extensión
  `pg_stat_statements`: al restaurar vuelven los trabajos en cola de ese momento.

## Cobros de las hijas, logias de dos niveles y CI (25-oct, desplegado: d4445dc)

- ✅ El admin de la raíz veía los miembros de sus logias hijas pero no sus cobros, cortes ni reportes
  (en producción: el admin de la raíz 6 no veía los 662 cobros de la logia 1). Ahora todo usa
  `logia_ids_accesibles`. Los admins de una logia hija siguen viendo solo la suya. Comprobado en
  producción: el admin de la 6 ve 662 cobros, el de la 1 ve 662 y el de la 7 ve 0.
- ✅ Las logias solo tienen dos niveles; se valida al cambiar el padre.
- ✅ La logia 4 (vacía) colgaba de la 1, que ya es hija de la 6: tres niveles. Por decisión de Héctor
  pasó a ser hija de la 6, con el código LOG003 (el suyo, LOG002, ya lo tenía la 9 en la misma
  organización). Copia previa: `comunia-20261025-1832`. Ya no queda ninguna logia en tres niveles.
- ✅ CI: el lint fallaba desde el 13-jul (892 corchetes sin espacios, el estilo de todo el
  proyecto); `.rubocop.yml` lo acepta y el resto se autocorrigió (solo espacios, un `return` y unas
  comillas). Trabajo nuevo `test` con Postgres 17: los 4 trabajos en verde y 194 pruebas en GitHub.
- ✅ Dependencias JS (99e6d07): `yarn upgrade` dentro de los rangos; `yarn audit` pasa de 25 avisos
  (17 altos, todos de herramientas de compilación: sass, postcss y compañía) a 0. El CSS compilado
  es el mismo salvo la notación de algunos colores. Desplegado.
- Análisis: brakeman, bundle-audit, importmap audit, yarn audit y rubocop sin avisos.

## Monitor de disponibilidad y errores (25-oct, desplegado: 272e98b)

- ✅ `/salud`: como `/up`, pero además pregunta a la base; si no llega, 503 sin detalle.
- ✅ `.github/workflows/disponibilidad.yml`: cada 15 min, desde GitHub (fuera de asus), tres intentos
  a `/salud`. Si falla, la ejecución sale en rojo y GitHub avisa al dueño del repo. Solo corre
  desde `main`; la primera ejecución (a mano, 25-oct 18:34) salió en verde. GitHub apaga las programaciones tras 60 días sin actividad en el repo.
- ✅ Errores 500 de peticiones y trabajos en `errores_app`, agrupados por huella, sin parámetros ni
  ruta. Página `/errores` en el panel de plataforma (con contador en el menú). La primera vez de cada
  huella, o si vuelve tras «Resuelto», notificación a los superadmins. De DENUNCIAPP no se guarda
  el mensaje.
- ⏳ Los dos superadmins de producción tienen 0 suscripciones push: el aviso solo se ve al entrar,
  hasta que activen las notificaciones en el móvil.

## Resumen semanal de cumpleaños (25-oct, desplegado: 8552f68)

- ✅ `CumpleanosSemanaJob`, los lunes a las 7:05: a cada miembro activo, una notificación con los
  cumpleaños de familiares de su organización en los próximos 7 días (nombre, parentesco, de quién
  y día). Nada de otras organizaciones. Enlaza a `/hospitalia/cumpleanos?rango=7`. El aviso del
  mismo día sigue igual. En producción solo cuentan los familiares de miembros activos (59 de 67): el
  primer resumen con contenido sería el lunes 16-nov (1 cumpleaños, a los 28 activos de la logia 1);
  antes no se envía nada.
- ✅ 29 de febrero: `MiembroFamiliar#proximo_cumpleanos` lo pasa al 28 en años no bisiestos. Antes
  la página de cumpleaños y el aviso diario lo saltaban, y el dashboard se quedaba sin ningún dato
  de módulos (el `Date::Error` lo tragaba el `rescue`). Hoy no hay ninguno en producción.

## Periodos de cobro por organización (25-oct)

- Antes un periodo era único por año y mes en toda la plataforma, y `generar_cobros!` cobraba a
  los miembros de todas las organizaciones. Ya hay dos en producción (Gran Logia de Colombia y Club
  Mercedez), aunque solo la logia 1 tiene miembros. Además, cualquier admin veía en la lista los
  periodos de las demás.
- Ahora cada periodo tiene `tenant_id`, que apunta a la logia raíz. Es único por organización, año
  y mes, y solo cobra a los miembros de esa organización y de sus logias hijas.
- El superadmin elige la organización al crear el periodo; los demás crean siempre en la suya. En
  el panel de plataforma la lista enseña la columna «Organización»; dentro de una organización solo
  salen sus periodos. Un periodo ajeno da 404.
- En el detalle del periodo, el admin de la raíz ya ve los cobros de sus logias hijas.
- `generar_cobros!`: una logia sin tarifa ni desglose daba cuota 0 y la generación se rompía. Ahora
  usa el monto del periodo.
- La migración 20261026010000 asigna cada periodo a la organización de sus cobros (si no tiene, a
  la de su creador). En producción, los 28 periodos van a la Gran Logia de Colombia (6). Simulado
  antes con una consulta de solo lectura.
- También se tocaron el desplegable de periodos en Cobros, `sync_pagos_sheets` y los seeds.
- Tesorería y reportes (`logia_ids_tesoreria`): dentro de una comunidad, el superadmin solo ve la
  tesorería de esa comunidad (todas, solo en el panel de plataforma). El filtro por logia aparece
  cuando hay más de una, así que el admin de la raíz puede filtrar por sus grupos. Si en
  Recaudación se escribe una fecha mal en la URL, se usa la fecha por defecto en vez de dar un 500.
- Héctor (25-oct): COMUNIA es para comunidades de todo tipo (Club Mercedez, Club BMW, egresados,
  vecinos), no solo logias. Los textos nuevos usan «comunidad» y «grupo».

## Categorías de comunidad (25-oct)

- Héctor (25-oct): «Categoría Club, Grupo Mercedes Benz, Nombre SUV»; «Categoría Barrio, Grupo
  Cedritos, Nombre Alborada 140»; «Categoría Universidad, Grupo Egresados, Nombre Cohorte 2023-2».
  Lo configura el superadmin por tipología.
- En el código: Categoría = modelo `Categoria`; Grupo = la comunidad raíz (`Logia` sin `tenant_id`);
  Nombre = la logia hija. La categoría solo se asigna a la raíz y sus grupos la heredan.
- Una categoría fija seis palabras (persona, grupo, cobro, reunión, fondo de ayuda, documentos) y
  qué módulos se ven: tesorería, documentos, biblioteca, fondo de ayuda, negocios y grados. Muro,
  chat, encuestas, directorio, calendario y cumpleaños están siempre.
- Cada palabra sale del grupo; si no la tiene, de la comunidad; si no, de la categoría; y si no, la
  de por defecto (`Logia::TERMINOS_POR_DEFECTO`). Una comunidad sin categoría ve todos los módulos.
- Un módulo apagado desaparece del menú y de los paneles, y su ruta lleva al panel
  (`requiere_modulo!`). Sin grados no se ve el grado en miembros y directorio, y todos ven todos
  los documentos.
- Pantalla: Panel de plataforma → Categorías (`/categorias`). La categoría de cada comunidad se
  elige en Tenants → Configurar.
- La migración 20261026020000 crea Masonería, Club, Barrio y Universidad. Asigna Club a las
  comunidades cuyo nombre empieza por «club» y Masonería a las demás. Vacía «Logias» como palabra de
  grupo, que era un plural puesto a mano. Los seeds crean las mismas cuatro.
- Lo que cambia en producción: el Club Mercedez deja de ver grados; la Gran Logia sigue igual.

## Reuniones (26-oct, desplegado: 47c48c6, aprobado por Héctor)

- Héctor eligió «Módulo de reuniones, pero SOLO en rama versionada con pruebas: sin desplegar ni migrar
  producción hasta que Héctor lo apruebe». Nada de esto está en main ni en producción.
- Una reunión se llama según la categoría (Reunión, Tenida, Encuentro, Asamblea) y es un módulo más
  («reuniones»). La migración 20261026030000 lo enciende en todas las categorías que ya existen.
- Convoca el admin de un grupo (rol admin_logia, en los grupos que gestiona), el superadmin o quien tenga
  un cargo vigente en su grupo. Si se convoca en la raíz, se convoca a toda la comunidad.
- Cada persona ve las de su grupo y las de la raíz; quien gestiona, también las de sus grupos. Nada sale
  de la organización (`AlcanceReuniones`).
- Al convocar se crea su evento en el calendario, y confirmar en uno es confirmar en el otro. Si se
  cancela, el evento desaparece. Desde el calendario, el evento de una reunión lleva a la reunión.
- Después se marca quién asistió (solo cuentan los convocados) y sale el quórum. El acta es un borrador
  que solo ve quien gestiona hasta que se publica.
- Avisos (`NotificarReunionJob`): convocatoria, cambio de fecha o lugar, cancelación y acta publicada.
  `RecordatorioReunionesJob` corre cada hora (en `config/recurring.yml`, producción) y avisa una sola vez
  el día antes, salvo a quien dijo que no iba.
- El panel muestra la próxima, con «Asistiré» / «No puedo» a un clic.
- Plural en español: `Logia.plural` (Reunión → Reuniones). Sustituye a `.pluralize`, que es inglés,
  en las palabras de la comunidad de las vistas.
- Para desplegar: fusionar la rama en main, copia previa y `bin/deploy`. Las migraciones corren solas.
  El primer recordatorio llegaría en la hora siguiente a desplegar, y solo si alguien ya convocó.

## Votaciones en las reuniones (26-oct, desplegado: bbc6e08, aprobado por Héctor)

- Dentro de una reunión, quien la gestiona abre una pregunta de sí / no / abstención y se avisa a los
  convocados. Votan solo los convocados, un voto por persona; se puede cambiar mientras está abierta.
- Mientras está abierta solo se ve cuántos votaron y la participación, para no arrastrar el voto. Al
  cerrarla salen los totales y «Aprobada» si hay más sí que no. Es secreta por defecto; si no lo es, se ve
  quién votó qué.
- Tablas `reunion_votaciones` y `reunion_votos` (migración 20261026080000).

## Invitar en bloque (26-oct, desplegado: c00b7e6, aprobado por Héctor)

- Producción: de 28 miembros activos, ninguno ha usado una invitación y solo 1 tiene celular. Invitar uno a
  uno desde cada ficha no escala.
- `/miembros/acceso` (enlace «Invitar a quienes faltan» en la lista de miembros): los activos de la
  comunidad que aún no han entrado y que el admin puede invitar (`invitar?`: miembros rasos, nunca la propia
  cuenta ni otro admin). Quien ya entró no aparece, porque invitarlo le quita la contraseña; el servidor lo
  descarta aunque llegue su id.
- Se marca a quién invitar y se apunta el celular. Al enviar se guardan los celulares y se generan los
  enlaces; la respuesta los pinta una sola vez, sin caché y sin flash, con «Enviar por WhatsApp» y «Copiar
  mensaje». Un celular mal escrito no guarda nada. Sin correos. Sin migraciones.
- El teléfono del miembro ahora se valida: hasta 20 caracteres, solo números, espacios y + ( ) - .

## Reuniones que se repiten (26-oct, desplegado: 5086354, aprobado por Héctor)

- Al convocar se elige «¿Se repite?»: cada semana, cada dos semanas o cada mes el mismo día de la semana (el
  segundo martes; si era el quinto, el último del mes), y cuántas fechas (2 a 12).
- Cada fecha es una reunión normal, con su evento, confirmación, asistencia, acta y recordatorio, unidas
  por la columna `serie` (migración 20261026100000). Se avisa una sola vez por la serie, no por cada fecha.
- En la lista solo sale la fecha más cercana de cada serie; la ficha enseña las siguientes. Se puede
  cancelar solo esa fecha o esa y las siguientes (un solo aviso). Editar cambia solo esa fecha.

## Añadir a mi calendario (26-oct, desplegado: 5086354, aprobado por Héctor)

- Push no está activo en casi nadie y no hay correo: que avise el calendario del teléfono. Cada evento del
  calendario y cada reunión que está convocada tienen «Añadir a mi calendario», con dos opciones:
  - Google Calendar: solo lleva el título, las horas, el lugar y el enlace a la app; la descripción no sale.
  - .ics (iPhone, Outlook): `/calendario/:id.ics`, con el título, las horas, el lugar, la descripción y el
    enlace. Se genera sin gema (`app/services/ics.rb`), con el texto escapado y las líneas plegadas.
- Solo lo baja quien ve el evento (mismo alcance de organización), con `no-store`. Sin migraciones.

## Calendario en el teléfono (26-oct, desplegado: e15f96f, aprobado por Héctor)

- Añadir evento por evento no escala con las series. Cada quien crea en «Calendario → Ver en mi teléfono»
  (`/calendario/suscripcion`) su dirección personal y se suscribe una vez: Google Calendar (`?cid=webcal://…`),
  iPhone/Mac/Outlook (`webcal://`) o copiar la URL. Su app la pide sola (`REFRESH-INTERVAL` 4 h) y las
  reuniones nuevas, cambiadas o canceladas aparecen o desaparecen solas.
- Lleva lo mismo que esa persona ve en el calendario de la app (su grupo y los sincronizados), desde un mes
  atrás hasta un año adelante, máximo 500. Nada de otra comunidad.
- La dirección: `/calendario/feed.ics?token=<semilla 24 hex + HMAC 40 hex>`. La semilla va en
  `users.calendario_semilla` (migración 20261026120000, índice único); la firma sale de `secret_key_base`, así
  que la base de datos sola no basta para fabricarla. «Cambiar la dirección» anula la anterior; «Dejar de
  compartir» la borra. La llave va en la query para que el log la muestre como `[FILTERED]`.
- El controlador del feed hereda de `ActionController::Base` (los calendarios no son navegadores modernos ni
  tienen sesión), con `rate_limit` 30/min y `no-store`. Deja de responder (404) si la cuenta está bloqueada, es
  solo de la red o el miembro hoy no está activo.
- De paso, el filtro del calendario dice «Mi <grupo>» y «Toda la comunidad» en vez de «Mi Logia» y «Todo el
  Tenant».

## Calendario: lo de la raíz llega a sus grupos (26-oct, desplegado: c17b8ab, aprobado por Héctor)

- Al probar el feed en producción salió vacío para los 28 miembros: están en el grupo 1 y los 24 eventos
  futuros (serie «Tenida Propagadores de la Luz») están en la raíz, el grupo 6. Dentro de la app sí los ven
  porque `/t/<slug>` solo admite raíces y allí `current_logia` es la raíz. El feed partía de `user.logia`.
- Ahora el calendario de un grupo incluye la raíz de su comunidad, como ya hacían las reuniones
  (`CalendarioSincronizacion.logia_ids_visibles_para(logia)`). Los grupos hermanos siguen sin verse, y desde
  un grupo «Toda la comunidad» es el grupo y la raíz.
- No se mueven los eventos al grupo 1: dentro de la app (contexto de la raíz) dejarían de verse en «Mi grupo».
- Comprobado en producción: el feed de un miembro del grupo 1 trae las 28 tenidas (24 próximas y 4 del último
  mes). Ahí salió que el enlace de cada evento usaba `/t/<slug del grupo>`, que da «Tenant no encontrado»
  porque `/t/` solo admite raíces. Arreglado y desplegado (69c80ea, aprobado por Héctor): usa el slug de la
  raíz.

## Próximos eventos en el panel (26-oct, desplegado: 8ab03f0, aprobado por Héctor)

- El panel solo enseñaba la próxima reunión; las tenidas de «Propagadores de la Luz» son eventos del
  calendario y no salían al entrar. Ahora, bajo la próxima reunión, «Próximos eventos»: hasta 3 de los
  próximos 30 días, con «Asistiré / No puedo» a un clic (o «Vas a ir / No vas» y «Cambiar»), y un enlace a
  «Ver en mi teléfono». En el panel del miembro y en el del admin.
- Alcance: el de las reuniones (`logia_ids_de_reuniones`: su grupo, la raíz y los grupos que gestiona), sin
  los eventos de reuniones (`where.missing(:reunion)`), que ya tienen su tarjeta.
- `CalendarioEvento.en_rango` y `ordenados` califican la tabla para poder unirse con `reuniones`.
- Prueba en producción: un miembro del grupo 1 ve las tenidas del 28-oct, 4-nov y 11-nov con sus botones; panel 200,
  0 errores, sin crear confirmaciones. Ojo: la visita simulada marcó su `last_seen_at` (lo hace
  `touch_last_seen!`); estaba vacío en la copia de las 13:20 y se devolvió a vacío.

## Quién usa la app, en el panel del admin (26-oct, desplegado: 1c2fb0d, aprobado por Héctor)

- Producción, 26-oct: de 28 miembros activos, 4 han entrado alguna vez (el último en mayo) y el admin del
  grupo no entra desde junio; 0 invitaciones usadas. Las mejoras no sirven si nadie entra, y quien lleva el
  grupo no lo ve en ningún sitio.
- Tarjeta «Quién usa la app» bajo los próximos eventos, solo en el panel del admin: «N de M han entrado
  alguna vez · K esta semana», barra de progreso, invitados sin entrar y los que faltan por invitar (o con la
  invitación caducada), y el botón «Invitar a quienes faltan» (`/miembros/acceso`) si puede invitar.
- Cuenta los miembros activos del mismo alcance que «activos» del panel (`ids_tenant`), con `User#acceso`.
  Sin migraciones.
- Prueba en producción como el admin del grupo (cuenta 48, `last_seen_at` guardado y restaurado): «4 de 28 …
  · 0 esta semana», 0 invitados, 24 sin invitar, con el botón; 0 errores.

## Bienvenida con la primera acción (26-oct, desplegado: 034a253, aprobado por Héctor)

- Quien acepta la invitación llega a `/bienvenida`: avisos e instalar la app, y nada que hacer dentro. Ahora
  añade «3. Las fechas en tu calendario» (botón «Ver en mi teléfono») y, debajo, la próxima reunión y los
  próximos eventos con «Asistiré / No puedo»: la primera visita termina con una respuesta y con las fechas en
  su calendario, que le recuerda sin push ni correo.
- «Novedades de la logia» pasa a «de tu comunidad».
- Sin migraciones. Prueba en `invitaciones_test.rb`.
- Prueba en producción como un miembro (cuenta 34, `last_seen_at` guardado y restaurado): sale la tenida con
  «Asistiré» y «Ver en mi teléfono» lleva a `/t/freemasons/calendario/suscripcion`.

## Recordatorio de los eventos del calendario (26-oct, desplegado: d6ae0e2, aprobado por Héctor)

- Las tenidas de «Propagadores de la Luz» son eventos del calendario, no reuniones, así que nadie recibía el
  «Mañana: …» que sí tienen las reuniones. `RecordatorioEventosJob` (cada hora, minuto 25): a los eventos que
  empiezan en las próximas 24 h y sin recordatorio, una notificación (y push a quien lo activó) «Mañana: título»
  (u «Hoy» si ya es el día), «hora · lugar. ¿Vas a ir?», con enlace al evento. Una sola vez por evento.
- Destinatarios: los miembros activos del grupo del evento; si es de la raíz, los de todos sus grupos (lo mismo
  que se ve en el calendario). Nunca otra comunidad, ni quien dijo «No puedo». Los eventos de una reunión los
  sigue recordando la reunión.
- Columna `calendario_eventos.recordatorio_enviado_at` (migración 20261026140000); se vacía si cambia el inicio.
- En producción, la primera la recibirían los 28 miembros activos (todos en el grupo 1) el 27-oct hacia las
  18:25, para la tenida del 28; sin push activado, solo la verán en la campana al entrar. Desplegado: `recordatorio_eventos` programado (cada hora, minuto 25);
  la tenida del 28-oct a las 18:00 aún sin recordatorio, como se esperaba.

## Índices únicos que faltaban (26-oct, desplegado: 3abceda, aprobado por Héctor)

- Cuatro validaciones de unicidad no tenían índice único, así que un doble clic o un reintento podía crear el
  duplicado: `miembros.user_id` (una persona con dos fichas: `user.miembro` cogería una cualquiera),
  `negocio_reportes` (anuncio, usuario), `conceptos_cobros` (logia, nombre) y `red_comunidades` lower(nombre).
- Migración 20261026150000. En producción no había duplicados (comprobado el 26-oct), así que crea los índices
  sin tocar datos. Desplegado y comprobado: los 4 índices en producción, 0 errores.
- `test/models/indices_unicos_test.rb` revisa todos los modelos: una validación de unicidad nueva sin su índice
  hace fallar la suite.

## Eventos del calendario como reunión (26-oct, desplegado: 1554ef9, aprobado por Héctor)

- Las tenidas de «Propagadores de la Luz» son una serie semanal del calendario (53 fechas, 24 futuras, en la
  raíz, creadas por la cuenta 48), así que no tienen orden del día, asistencia con quórum, acta ni votaciones,
  que son de las reuniones. Ahora, en un evento, quien lo gestiona ve «Llevar como tenida (esta y las N
  siguientes)»: cada fecha pasa a ser una reunión del grupo elegido (solo los que esa persona convoca: para la
  cuenta 48, su grupo), en una misma serie de reuniones. Se conservan las respuestas y no se avisa a nadie.
- Las fechas llevadas salen de la serie del calendario y esta termina el día anterior: editar o borrar la serie
  (que regenera con `delete_all`) ya no las toca. El recordatorio pendiente lo manda la reunión, no el evento.
- Hasta 60 fechas de una vez. Lo de otra comunidad, de un grupo que no se convoca o ya llevado da 404.
- Sin migraciones. `test/integration/evento_a_reunion_test.rb` (4 pruebas).
- Prueba en producción como la cuenta 48 (`last_seen_at` guardado y restaurado), sin pulsar: en la tenida del
  28-oct sale «Llevar como tenida (esta y las 23 siguientes)», solo con su grupo (1). 0 reuniones, 0 errores.
  Las tenidas siguen como eventos hasta que alguien pulse el botón.

## Asistencia con QR (26-oct, desplegado: b6b7028, aprobado por Héctor)

- Quien gestiona la reunión pulsa «QR de asistencia» y lo enseña en la sala (pantalla o teléfono). Cada
  convocado lo escanea con la cámara, pulsa «Estoy aquí» y queda en la lista; quien gestiona la revisa en
  «Registrar asistencia» (ya marcados) y al guardarla la da por celebrada, como antes. La app se abre en cada
  tenida y el quórum se arma solo.
- Solo vale con el código de esa reunión (24 caracteres, uno por reunión), desde una hora antes hasta una hora
  después, para sus convocados y si no está cancelada. Abrir el enlace no registra nada: hace falta el botón.
- Sin sesión, el QR lleva al login y de vuelta al botón: el login ahora vuelve a la página de la que se venía
  (`stored_location_for`), también para los enlaces de los avisos.
- Gema `rqrcode` (SVG en el servidor, sin JavaScript). Migración 20261026195839 (`reuniones.codigo_asistencia`,
  índice único); las reuniones de antes reciben su código al enseñar el QR.
- `test/integration/asistencia_qr_test.rb` (4 pruebas).

## Llevar como reunión desde el panel (26-oct, desplegado: d03b5d0, aprobado por Héctor)

- En «Próximos eventos» del panel, quien puede llevar un evento como reunión (quien lo creó o gestiona su
  grupo, con un grupo que se convoca) ve «Llevar como tenida (orden del día, quórum y QR)». Lleva a la página
  del evento, que explica qué cambia y pide confirmación; desde el panel no se crea nada.
- Por qué: en producción hay 0 reuniones, porque las tenidas siguen como eventos de la serie del calendario y
  el botón solo estaba dentro del evento. La del 28 la creó el admin de Propagadores (cuenta 48): lo verán él
  y los superadmins; los socios, no.
- Prueba nueva en `test/integration/evento_a_reunion_test.rb`.

## Pendiente de Héctor

(Nada de esto se hace en el piloto.)

- Que los miembros de la logia **entren y creen su perfil** en `/red`: hoy han entrado 1 de 41 y
  ninguno tiene perfil. Cuando se despliegue, con las invitaciones por WhatsApp. Solo 1 miembro
  tiene teléfono guardado; para los demás el botón abre WhatsApp sin destinatario.
- **Servicio de correo**: sin él no hay recuperación de contraseña ni confirmación de correo para las
  cuentas de la red. Activarlo es solo poner en `app.env` SMTP_ADDRESS, SMTP_PORT, SMTP_USERNAME,
  SMTP_PASSWORD y MAIL_FROM (de un dominio propio) y desplegar; sin SMTP_ADDRESS no se envía nada.
- **Cuenta de R2**: confirmar que la de las variables R2_* (2 adjuntos y los nuevos) es suya y no de
  Picap.
- **Para la revisión legal**: a los miembros de una logia certificada se les da la membresía sin
  consentimiento expreso; no se ven hasta que crean su perfil y aceptan la política.
- **Turnstile**: claves en una cuenta de Cloudflare suya, nunca de Picap. Sin ellas, en producción
  no se aceptan registros ni contactos sin cuenta.
- **Revisión legal**: política de tratamiento de datos (Ley 1581) y términos de la red.
- Quién hace de **certificador/moderador de plataforma** además del superadmin.
- **Responsable del tratamiento** y canal de atención para la página de privacidad, que hoy dice
  «se publicarán aquí antes de abrir la red al público».

### Arrastrado de antes

- DENUNCIAPP (apagada): claves de Turnstile, correo, DENUNCIAS_CONTACTO, revisión legal, aspecto,
  HEIC/WebP. Después, la clave de Tailscale en `ts-denunciapp.env`, `bin/deploy` y DENUNCIAPP_URL.
- client_id de Drive: proyecto «rclone-copias» en la cuenta personal (encargado a Tmux, sin
  respuesta). Después, un remoto con `drive.file` y pasar a él COMUNIA, Rival y Prestandonos.
- Borrar el proyecto «rclone-hector» de Picap. Avisar a los usuarios de la URL nueva.
