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
- Arreglo 1fedecf (local, sin desplegar): la tarea diaria vuelve a sincronizar las logias
  certificadas. Sin él, las altas y bajas no llegan a la comunidad y las membresías vencen al año
  sin nadie que las renueve. Hasta desplegarlo, basta con volver a certificar la logia a mano.

## Pendiente de Héctor

(Nada de esto se hace en el piloto.)

- **Desplegar 1fedecf** (sincronización diaria de logias).
- Que los miembros de la logia **creen su perfil** en `/red`: hoy ninguno lo tiene.
- **Servicio de correo**: sin él no hay recuperación de contraseña ni confirmación de correo para las
  cuentas de la red.
- **Turnstile**: claves en una cuenta de Cloudflare suya, nunca de Picap. Sin ellas, en producción
  no se aceptan registros ni contactos sin cuenta.
- **Revisión legal**: política de tratamiento de datos (Ley 1581) y términos de la red.
- Quién hace de **certificador/moderador de plataforma** además del superadmin.
- **Responsable del tratamiento** y canal de atención para la página de privacidad, que hoy dice
  «se publicarán aquí antes de abrir la red al público».
- Decidir si la red se anuncia desde la portada de COMUNIA: hoy solo se llega por `/red`.

### Arrastrado de antes

- DENUNCIAPP (apagada): claves de Turnstile, correo, DENUNCIAS_CONTACTO, revisión legal, aspecto,
  HEIC/WebP. Después, la clave de Tailscale en `ts-denunciapp.env`, `bin/deploy` y DENUNCIAPP_URL.
- client_id de Drive: proyecto «rclone-copias» en la cuenta personal (encargado a Tmux, sin
  respuesta). Después, un remoto con `drive.file` y pasar a él COMUNIA, Rival y Prestandonos.
- Borrar el proyecto «rclone-hector» de Picap. Avisar a los usuarios de la URL nueva.
