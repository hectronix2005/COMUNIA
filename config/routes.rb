Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  # Entrada/salida de contexto de tenant (fuera del scope opcional).
  get    "t/:slug", to: "tenant_access#enter",       as: :enter_tenant
  delete "t",       to: "tenant_access#exit_tenant", as: :exit_tenant

  # Todas las rutas aceptan opcionalmente el prefijo /t/:tenant_slug/ para
  # que tras el login la URL conserve el contexto del tenant.
  scope "(/t/:tenant_slug)", constraints: { tenant_slug: /[a-z0-9][a-z0-9\-_]*/ } do
    devise_for :users, path: "", path_names: {
      sign_in: "login",
      sign_out: "logout"
    }

    get "dashboard", to: "dashboard#index", as: :dashboard

  # ── Plataforma COMUNIA (sin subdominio, super admin) ──────────
  resources :users, only: [:edit, :update]

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

  # ── Red Social ────────────────────────────────────────────
  get  "chat", to: "chat#index",  as: :chat
  post "chat", to: "chat#create"

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
end
