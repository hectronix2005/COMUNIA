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
4. 🔄 Perfiles (hoja de vida incluida) y publicaciones necesito/ofrezco con alcance
5. ⏳ Fórmula de confianza y antifraude: cuarentena, topes, anillos, duplicados, filtros de estafa
6. ⏳ Búsqueda pública sin cuenta, filtros y categorías. Pruebas de extracción de la privacidad
7. ⏳ Mensajería intermediada, contacto sin cuenta, reseñas verificables, reportes y moderación,
   notificaciones
8. ⏳ Administración de comunidades y métricas, Ley 1581 (exportar, borrar), onboarding,
   accesibilidad, datos de demostración sintéticos, README

## Pendiente de Héctor

(Nada de esto se hace en el piloto.)

- **Desplegar la red social en producción** (asus): migraciones y `bin/deploy`. El piloto solo
  comitea en local.
- **Servicio de correo**: sin él no hay recuperación de contraseña ni confirmación de correo para las
  cuentas de la red.
- **Turnstile**: claves en una cuenta de Cloudflare suya, nunca de Picap. Sin ellas, en producción
  no se aceptan registros ni contactos sin cuenta.
- **Revisión legal**: política de tratamiento de datos (Ley 1581) y términos de la red.
- Quién hace de **certificador/moderador de plataforma** además del superadmin.

### Arrastrado de antes

- DENUNCIAPP (apagada): claves de Turnstile, correo, DENUNCIAS_CONTACTO, revisión legal, aspecto,
  HEIC/WebP. Después, la clave de Tailscale en `ts-denunciapp.env`, `bin/deploy` y DENUNCIAPP_URL.
- client_id de Drive: proyecto «rclone-copias» en la cuenta personal (encargado a Tmux, sin
  respuesta). Después, un remoto con `drive.file` y pasar a él COMUNIA, Rival y Prestandonos.
- Borrar el proyecto «rclone-hector» de Picap. Avisar a los usuarios de la URL nueva.
