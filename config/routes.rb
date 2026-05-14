Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

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

  devise_for :users, path: "", path_names: {
    sign_in: "login",
    sign_out: "logout"
  }

  get "dashboard", to: "dashboard#index", as: :dashboard

  # ── Plataforma COMUNIA (sin subdominio, super admin) ──────────
  resources :users, only: [:edit, :update]

  # Perfil personal: cada usuario puede editar su nombre visible en el chat.
  get   "perfil", to: "perfil#edit",   as: :perfil
  patch "perfil", to: "perfil#update"

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
  resources :miembros do
    member do
      get   :cambiar_estado
      patch :cambiar_estado
      patch :cambiar_rol
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
