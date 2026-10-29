Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  # /up y además la base, para el monitor externo (.github/workflows/disponibilidad.yml).
  get "salud" => "salud#show"

  # ── PWA ──────────────────────────────────────────────────────
  get "manifest"      => "pwa#manifest", as: :pwa_manifest, defaults: { format: "json" }
  get "service-worker" => "pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"

  # Entrada/salida de contexto de tenant. El middleware TenantPathPrefix
  # reescribe /t/:slug/<resto> → /<resto> con SCRIPT_NAME=/t/:slug, por lo
  # que todas las rutas siguen siendo no-prefijadas aquí y Rails inyecta
  # automáticamente el prefijo al generar URLs.
  get    "t/:slug", to: "tenant_access#enter",       as: :enter_tenant
  delete "t",       to: "tenant_access#exit_tenant", as: :exit_tenant

  # Las rutas de invitación de la gema se omiten: su «new/create» deja invitar a cualquier usuario con
  # sesión, y su «remove» borra la cuenta con solo tener el enlace. Aquí solo se acepta; invitar se hace
  # desde la ficha del miembro (MiembrosController#invitar), con permiso.
  devise_for :users, path: "", skip: [:invitations], path_names: {
    sign_in: "login",
    sign_out: "logout"
  }
  devise_scope :user do
    get   "invitacion", to: "invitaciones#edit",   as: :accept_user_invitation
    patch "invitacion", to: "invitaciones#update", as: :user_invitation
    put   "invitacion", to: "invitaciones#update"
  end
  get "bienvenida", to: "bienvenida#show", as: :bienvenida

  get "dashboard", to: "dashboard#index", as: :dashboard

  # ── Panel del operador de DENUNCIAPP (host de COMUNIA, solo superadmin) ──
  scope "denuncias/admin", module: :denuncias, controller: :admin do
    get  "/",                          action: :index,             as: :denuncias_admin
    post "retiros/:id/:decision",      action: :resolver_retiro,   as: :denuncias_admin_retiro, constraints: { decision: /aceptar|rechazar/ }
    post "reportes/:id/retirar",       action: :retirar,           as: :denuncias_admin_retirar
    post "reportes/:id/restaurar",     action: :restaurar,         as: :denuncias_admin_restaurar
    get  "reportes/:id/custodia",      action: :custodia,          as: :denuncias_admin_custodia
    post "reportes/:id/paquete",       action: :paquete,           as: :denuncias_admin_paquete
    post "evidencias/:id/original",    action: :original,          as: :denuncias_admin_original
    post "recompensas",                action: :crear_recompensa,  as: :denuncias_admin_recompensas
    post "recompensas/:id/vencer",     action: :vencer_recompensa, as: :denuncias_admin_vencer
  end

  # ── DENUNCIAPP: el muro es público; denuncian los miembros activos con su sesión ──
  scope "denuncias", module: :denuncias, as: :denuncias, constraints: { id: /[0-9a-f-]{36}/ } do
    get  "/",                   to: "reportes#index",  as: :muro
    post "/",                   to: "reportes#create"
    get  "nueva",               to: "reportes#new",    as: :nueva
    get  "mias",                to: "reportes#mias",   as: :mias
    post ":id/retirar",         to: "reportes#retirar", as: :retirar
    get  ":id/retiro",          to: "retiros#new",     as: :retiro
    post ":id/retiro",          to: "retiros#create"
    get  "terminos",            to: "paginas#terminos", as: :terminos
    get  "fotos/:archivo",      to: "reportes#foto",   as: :foto, constraints: { archivo: /[0-9a-f-]+\.(jpg|png)/ }, format: false
  end

  # ── Red de comunidades certificadas (app/models/red.rb) ─────────
  # Buscar, ver lo público y escribir sin cuenta no exige sesión; lo demás, sí.
  scope "red", module: :red, as: :red do
    get  "/",                 to: "inicio#index",     as: :inicio
    get  "buscar",            to: "busqueda#index",   as: :buscar
    get  "como-funciona",     to: "paginas#como_funciona", as: :como_funciona
    get  "privacidad",        to: "paginas#privacidad", as: :privacidad
    get  "p/:token",          to: "perfiles#show",    as: :perfil
    get  "p/:token/hoja-de-vida", to: "perfiles#hoja_de_vida", as: :hoja_de_vida
    get  "registro",          to: "registros#new",    as: :registro
    post "registro",          to: "registros#create"
    post "reportar",          to: "reportes#create",  as: :reportar

    resources :publicaciones, only: %i[show new create edit update], param: :token do
      member do
        get  :contactar, to: "contactos#new"
        post :contactar, to: "contactos#create"
        post :renovar
        post :estado, action: :cambiar_estado
      end
    end
    get "mis-publicaciones", to: "publicaciones#mias", as: :mis_publicaciones

    resources :comunidades, only: %i[index show new create], param: :token do
      member do
        post   :unirse,   to: "membresias#create"
        delete :salir,    to: "membresias#destroy"
        get    :miembros, to: "membresias#index"
        get    :gestion,  to: "gestion#show"
        patch  :gestion,  to: "gestion#update"
        get    "gestion/miembros.csv", to: "gestion#exportar", as: :exportar, format: false
        post   "gestion/:perfil/:accion", to: "gestion#decidir", as: :decidir,
               constraints: { accion: /aprobar|rechazar|revocar|renovar|hacer_verificador|hacer_miembro/ }
      end
    end
    get "mis-comunidades", to: "membresias#mias", as: :mis_comunidades

    get    "mi-perfil",       to: "mi_perfil#edit",     as: :mi_perfil
    patch  "mi-perfil",       to: "mi_perfil#update"
    get    "bienvenida",      to: "mi_perfil#bienvenida", as: :bienvenida
    post   "bienvenida",      to: "mi_perfil#crear"
    get    "mi-perfil/datos", to: "mi_perfil#exportar", as: :mis_datos, defaults: { format: :json }
    delete "mi-perfil",       to: "mi_perfil#destroy"

    resources :conversaciones, only: %i[index show], param: :token do
      member do
        post :mensajes,  to: "conversaciones#escribir"
        post :compartir, to: "conversaciones#compartir_contacto"
        post :bloquear
        post :resena
      end
    end
    post "p/:token/escribir", to: "conversaciones#create", as: :escribir
    get  "avisos",            to: "avisos#index",     as: :avisos

    scope "moderacion", controller: :moderacion, as: :moderacion do
      get  "/",                          action: :index
      get  "metricas",                   action: :metricas,   as: :metricas
      post "comunidades/:token/:accion", action: :comunidad,  as: :comunidad,
           constraints: { accion: /certificar|rechazar|suspender|revocar/ }
      post "reportes/:id/:accion",       action: :reporte,    as: :reporte, constraints: { accion: /descartar|sancionar/ }
      post "publicaciones/:token/aprobar", action: :aprobar,  as: :aprobar
      post "logias/:id/certificar",      action: :certificar_logia, as: :certificar_logia
    end
  end
  devise_scope :user do
    get  "red/entrar", to: "red/sesiones#new",    as: :red_entrar
    post "red/entrar", to: "red/sesiones#create"
  end

  # ── Plataforma COMUNIA (sin subdominio, super admin) ──────────
  resources :users, only: [:edit, :update]

  # Perfil personal: cada usuario puede editar su nombre visible en el chat.
  get   "perfil", to: "perfil#edit",   as: :perfil
  patch "perfil", to: "perfil#update"

  # Errores registrados (ErrorApp), del superadmin.
  get   "errores",              to: "errores#index",    as: :errores
  get   "errores/:id",          to: "errores#show",     as: :error_registrado
  patch "errores/:id/resolver", to: "errores#resolver", as: :resolver_error

  resources :categorias, except: :show
  resources :tenants, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    member do
      post :preview
      post   :crear_admin_tenant
      delete :quitar_admin_tenant
    end
    collection { delete :exit_preview }
    resources :logias, only: [:new, :create, :edit, :update, :destroy],
              controller: "tenant_logias"
  end

  # ── Gestión interna de cada tenant (con subdominio) ───────────
  resources :logias, only: [:show, :edit, :update] do
    resources :conceptos_cobro, path: "conceptos"
    resources :tarifas, only: [:index, :new, :create, :edit, :update, :destroy]
  end
  # Pedir acceso con el código de la comunidad (público) y resolver esas solicitudes (administradores).
  # Modo invitado: la comunidad de demostración, solo para mirar (DemoController).
  post   "demo",            to: "demo#create",     as: :demo
  delete "demo",            to: "demo#destroy"
  get    "demo/participar", to: "demo#participar", as: :demo_participar

  get  "pedir-acceso",         to: "pedir_acceso#new",     as: :pedir_acceso
  post "pedir-acceso",         to: "pedir_acceso#create"
  get  "pedir-acceso/enviada", to: "pedir_acceso#enviada", as: :pedir_acceso_enviada
  scope "solicitudes", controller: :solicitudes_acceso do
    get  "/",              action: :index,          as: :solicitudes_acceso
    post "codigo",         action: :renovar_codigo, as: :renovar_codigo_acceso
    get  ":id",            action: :show,           as: :solicitud_acceso, constraints: { id: /\d+/ }
    post ":id/aprobar",    action: :aprobar,        as: :aprobar_solicitud_acceso, constraints: { id: /\d+/ }
    post ":id/rechazar",   action: :rechazar,       as: :rechazar_solicitud_acceso, constraints: { id: /\d+/ }
  end
  resources :miembros do
    collection do
      get  :acceso, action: :acceso_pendiente
      post :acceso, action: :invitar_pendientes, as: :invitar_pendientes
    end
    member do
      get   :cambiar_estado
      patch :cambiar_estado
      patch :cambiar_rol
      post  :invitar
    end
    resources :estado_cambios,
              only:       [:update],
              controller: "miembro_estado_cambios",
              path:       "historial"
    resources :cargos,
              only:       [:create, :update, :destroy],
              controller: "miembro_cargos"
  end

  resources :periodo_cobros, path: "periodos" do
    member do
      post :generar_cobros
    end
  end

  resources :cobros, only: [:index, :show] do
    collection do
      post :parsear_soporte
      get :adjuntar_soporte_multiple
      patch :subir_soporte_multiple
    end
    member do
      get :adjuntar_soporte
      patch :subir_soporte
      get :validar
      patch :confirmar_pago
      patch :rechazar_pago
    end
  end

  resources :reportes, only: [] do
    collection do
      get :cartera
      get :recaudacion
      get :morosos
      get :recibo, path: "recibo/:pago_id"
    end
  end

  resources :corte_conciliaciones, only: [:index, :show, :create, :destroy]

  resources :roles do
    resources :permisos, only: [:create, :destroy], controller: "rol_permisos"
  end

  # ── Notificaciones & Push ──────────────────────────────────
  resources :notificaciones, only: [:index] do
    member { patch :leer }
    collection { post :leer_todas }
  end
  post   "push_subscriptions", to: "push_subscriptions#create"
  delete "push_subscriptions", to: "push_subscriptions#destroy"

  # ── Directorio ──────────────────────────────────────────────
  resources :directorio, only: [:index, :show, :edit, :update]

  # ── Muro / Feed ──────────────────────────────────────────
  resources :publicaciones, only: [:index, :create, :destroy] do
    member do
      post :toggle_like
      post :comentar
      post :toggle_pin
    end
  end

  # ── Encuestas ──────────────────────────────────────────────
  resources :encuestas, only: [:index, :show, :new, :create] do
    member do
      post :votar
      post :cerrar
    end
  end

  # ── Reuniones ──────────────────────────────────────────────
  resources :reuniones, only: [:index, :show, :new, :create, :edit, :update] do
    post :desde_evento, on: :collection
    get  :constancia, on: :collection
    member do
      post :responder
      get  :asistencia
      post :asistencia, action: :registrar_asistencia, as: :registrar_asistencia
      post :publicar_acta
      get  :acta_pdf
      post :aprobar_acta_anterior
      post :deshacer_aprobacion
      get  :qr
      get  :presente
      post :presente, action: :marcar_presente, as: :marcar_presente
      post :cancelar
    end
    resources :votaciones, controller: "reunion_votaciones", only: [:create] do
      member do
        post :votar
        post :cerrar
      end
    end
    resources :propuestas, controller: "reunion_propuestas", only: [:create] do
      member do
        post :incluir
        post :descartar
      end
    end
    resources :acuerdos, controller: "reunion_acuerdos", only: [:create, :destroy] do
      post :cumplir, on: :member
    end
  end

  # ── RSVP Eventos ───────────────────────────────────────────
  resources :calendario, only: [] do
    resources :evento_confirmaciones, only: [:create]
  end

  # ── Red Social ────────────────────────────────────────────
  get  "chat",               to: "chat#index",        as: :chat
  post "chat",               to: "chat#create"
  post "chat/marcar_leido",  to: "chat#marcar_leido",  as: :chat_marcar_leido
  post "chat/reaccionar",    to: "chat#reaccionar",    as: :chat_reaccionar
  get  "chat/buscar",        to: "chat#buscar",        as: :chat_buscar
  post "chat/typing",        to: "chat#typing",        as: :chat_typing

  # ── Calendario ────────────────────────────────────────────
  get   "calendario/sincronizaciones",        to: "calendario#sincronizaciones",  as: :calendario_sincronizaciones
  post  "calendario/sincronizaciones",        to: "calendario#solicitar_sync",    as: :calendario_solicitar_sync
  patch "calendario/sincronizaciones/:id",    to: "calendario#responder_sync",    as: :calendario_responder_sync
  get    "calendario/suscripcion", to: "calendario#suscripcion",         as: :calendario_suscripcion
  post   "calendario/suscripcion", to: "calendario#renovar_suscripcion"
  delete "calendario/suscripcion", to: "calendario#anular_suscripcion"
  # La que pide el teléfono: sin sesión ni /t/<slug>; la llave va en ?token= para que el log la filtre.
  get    "calendario/feed.ics",    to: "suscripcion_calendario#show", as: :calendario_feed, format: false
  resources :calendario, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # ── Biblioteca ────────────────────────────────────────────
  resources :biblioteca_planchas, path: "biblioteca/planchas"
  resources :biblioteca_libros, path: "biblioteca/libros" do
    member { post :calificar }
  end

  # ── Hospitalia ────────────────────────────────────────────
  get    "hospitalia",                         to: "hospitalia#index",           as: :hospitalia
  get    "hospitalia/recaudos",                to: "hospitalia#recaudos",        as: :hospitalia_recaudos
  post   "hospitalia/recaudos",                to: "hospitalia#create_recaudo",  as: :hospitalia_create_recaudo
  delete "hospitalia/recaudos/:id",            to: "hospitalia#destroy_recaudo", as: :hospitalia_destroy_recaudo
  get    "hospitalia/gastos",                  to: "hospitalia#gastos",          as: :hospitalia_gastos
  post   "hospitalia/gastos",                  to: "hospitalia#create_gasto",    as: :hospitalia_create_gasto
  delete "hospitalia/gastos/:id",              to: "hospitalia#destroy_gasto",   as: :hospitalia_destroy_gasto
  get    "hospitalia/cumpleanos",              to: "hospitalia#cumpleanos",      as: :hospitalia_cumpleanos
  post   "hospitalia/felicitacion",            to: "hospitalia#enviar_felicitacion", as: :hospitalia_enviar_felicitacion
  get    "hospitalia/familiares",              to: "hospitalia#familiares",      as: :hospitalia_familiares
  post   "hospitalia/familiares",              to: "hospitalia#create_familiar", as: :hospitalia_create_familiar
  delete "hospitalia/familiares/:id",          to: "hospitalia#destroy_familiar", as: :hospitalia_destroy_familiar

  # ── Negocios ──────────────────────────────────────────────
  resources :negocios, path: "negocios" do
    member do
      post   :toggle_favorito
      delete :remove_imagen
    end
    post "iniciar_conversacion", to: "negocio_conversaciones#create", as: :iniciar_conversacion
    post "reportar",             to: "negocio_reportes#create",       as: :reportar
  end
  resources :negocio_conversaciones, path: "mis-conversaciones", only: [:index, :show] do
    resources :mensajes, only: [:create], controller: "negocio_mensajes"
  end
end
