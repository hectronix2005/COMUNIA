# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_15_024936) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "biblioteca_calificaciones", force: :cascade do |t|
    t.bigint "libro_id", null: false
    t.bigint "user_id", null: false
    t.integer "puntuacion", null: false
    t.text "comentario"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["libro_id", "user_id"], name: "index_biblioteca_calificaciones_on_libro_id_and_user_id", unique: true
    t.index ["libro_id"], name: "index_biblioteca_calificaciones_on_libro_id"
  end

  create_table "biblioteca_libros", force: :cascade do |t|
    t.string "titulo", null: false
    t.string "autor"
    t.text "descripcion"
    t.string "categoria"
    t.integer "anio"
    t.string "url_externa"
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["categoria"], name: "index_biblioteca_libros_on_categoria"
    t.index ["logia_id"], name: "index_biblioteca_libros_on_logia_id"
    t.index ["user_id"], name: "index_biblioteca_libros_on_user_id"
  end

  create_table "biblioteca_planchas", force: :cascade do |t|
    t.string "titulo", null: false
    t.text "descripcion"
    t.string "grado", default: "Aprendiz", null: false
    t.string "autor"
    t.integer "anio"
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["grado"], name: "index_biblioteca_planchas_on_grado"
    t.index ["logia_id", "grado"], name: "index_biblioteca_planchas_on_logia_id_and_grado"
    t.index ["logia_id"], name: "index_biblioteca_planchas_on_logia_id"
    t.index ["user_id"], name: "index_biblioteca_planchas_on_user_id"
  end

  create_table "calendario_eventos", force: :cascade do |t|
    t.string "titulo", null: false
    t.text "descripcion"
    t.datetime "inicio", null: false
    t.datetime "fin", null: false
    t.boolean "todo_el_dia", default: false, null: false
    t.string "color", default: "#4285f4"
    t.string "ubicacion"
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recurrencia_tipo"
    t.integer "recurrencia_intervalo", default: 1
    t.string "recurrencia_dias"
    t.string "recurrencia_fin", default: "nunca"
    t.date "recurrencia_hasta"
    t.integer "recurrencia_count", default: 10
    t.bigint "serie_id"
    t.index ["inicio"], name: "index_calendario_eventos_on_inicio"
    t.index ["logia_id", "inicio"], name: "index_calendario_eventos_on_logia_id_and_inicio"
    t.index ["logia_id"], name: "index_calendario_eventos_on_logia_id"
    t.index ["serie_id"], name: "index_calendario_eventos_on_serie_id"
    t.index ["user_id"], name: "index_calendario_eventos_on_user_id"
  end

  create_table "calendario_sincronizaciones", force: :cascade do |t|
    t.bigint "logia_solicitante_id", null: false
    t.bigint "logia_destino_id", null: false
    t.bigint "solicitado_por_id", null: false
    t.string "estado", default: "pendiente", null: false
    t.text "mensaje"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["estado"], name: "index_calendario_sincronizaciones_on_estado"
    t.index ["logia_destino_id"], name: "index_calendario_sincronizaciones_on_logia_destino_id"
    t.index ["logia_solicitante_id", "logia_destino_id"], name: "idx_cal_sync_unique_pair", unique: true
    t.index ["logia_solicitante_id"], name: "index_calendario_sincronizaciones_on_logia_solicitante_id"
    t.index ["solicitado_por_id"], name: "index_calendario_sincronizaciones_on_solicitado_por_id"
  end

  create_table "cargos", force: :cascade do |t|
    t.string "nombre", null: false
    t.integer "logia_id", null: false
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["logia_id", "nombre"], name: "index_cargos_on_logia_id_and_nombre", unique: true
    t.index ["logia_id"], name: "index_cargos_on_logia_id"
  end

  create_table "chat_mensajes", force: :cascade do |t|
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.text "contenido"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "destinatario_id"
    t.string "canal", default: "logia", null: false
    t.index ["canal"], name: "index_chat_mensajes_on_canal"
    t.index ["logia_id"], name: "index_chat_mensajes_on_logia_id"
    t.index ["user_id"], name: "index_chat_mensajes_on_user_id"
  end

  create_table "cobros", force: :cascade do |t|
    t.bigint "periodo_cobro_id", null: false
    t.bigint "miembro_id", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.integer "estado", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["estado"], name: "index_cobros_on_estado"
    t.index ["miembro_id"], name: "index_cobros_on_miembro_id"
    t.index ["periodo_cobro_id", "miembro_id"], name: "index_cobros_on_periodo_cobro_id_and_miembro_id", unique: true
    t.index ["periodo_cobro_id"], name: "index_cobros_on_periodo_cobro_id"
  end

  create_table "conceptos_cobros", force: :cascade do |t|
    t.bigint "logia_id", null: false
    t.string "nombre", null: false
    t.decimal "monto", precision: 10, scale: 2, default: "0.0", null: false
    t.string "descripcion"
    t.boolean "activo", default: true, null: false
    t.integer "orden", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tipo", default: 0, null: false
    t.index ["logia_id", "orden"], name: "index_conceptos_cobros_on_logia_id_and_orden"
    t.index ["logia_id"], name: "index_conceptos_cobros_on_logia_id"
  end

  create_table "corte_conciliaciones", force: :cascade do |t|
    t.date "fecha_corte", null: false
    t.string "descripcion"
    t.integer "estado", default: 0, null: false
    t.jsonb "resultado", default: {}, null: false
    t.string "formato_archivo"
    t.integer "total_archivo", default: 0
    t.integer "total_sistema", default: 0
    t.bigint "logia_id", null: false
    t.bigint "creado_por_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creado_por_id"], name: "index_corte_conciliaciones_on_creado_por_id"
    t.index ["logia_id", "fecha_corte"], name: "index_corte_conciliaciones_on_logia_id_and_fecha_corte", unique: true
    t.index ["logia_id"], name: "index_corte_conciliaciones_on_logia_id"
  end

  create_table "hospitalia_gastos", force: :cascade do |t|
    t.string "concepto", null: false
    t.decimal "monto", precision: 12, scale: 2, null: false
    t.date "fecha", null: false
    t.text "descripcion"
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.bigint "beneficiario_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fecha"], name: "index_hospitalia_gastos_on_fecha"
    t.index ["logia_id"], name: "index_hospitalia_gastos_on_logia_id"
  end

  create_table "hospitalia_recaudos", force: :cascade do |t|
    t.string "concepto", null: false
    t.decimal "monto", precision: 12, scale: 2, null: false
    t.date "fecha", null: false
    t.text "descripcion"
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.bigint "miembro_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fecha"], name: "index_hospitalia_recaudos_on_fecha"
    t.index ["logia_id"], name: "index_hospitalia_recaudos_on_logia_id"
  end

  create_table "logias", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "codigo", null: false
    t.integer "rc_secuencia_actual", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nombre_app"
    t.string "icono"
    t.string "lema"
    t.string "color_primario"
    t.string "termino_miembro"
    t.string "termino_logia"
    t.string "termino_cobro"
    t.string "slug"
    t.bigint "tenant_id"
    t.index ["slug"], name: "index_logias_on_slug", unique: true
    t.index ["tenant_id", "codigo"], name: "index_logias_on_tenant_id_and_codigo", unique: true
    t.index ["tenant_id"], name: "index_logias_on_tenant_id"
  end

  create_table "miembro_cargos", force: :cascade do |t|
    t.integer "miembro_id", null: false
    t.integer "cargo_id", null: false
    t.date "desde", null: false
    t.date "hasta"
    t.integer "asignado_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cargo_id"], name: "index_miembro_cargos_on_cargo_id"
    t.index ["miembro_id"], name: "index_miembro_cargos_on_miembro_id"
  end

  create_table "miembro_estado_cambios", force: :cascade do |t|
    t.bigint "miembro_id", null: false
    t.string "estado", null: false
    t.date "desde", null: false
    t.date "hasta"
    t.string "motivo"
    t.bigint "registrado_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["miembro_id", "desde"], name: "index_miembro_estado_cambios_on_miembro_id_and_desde"
    t.index ["miembro_id"], name: "index_miembro_estado_cambios_on_miembro_id"
    t.index ["registrado_por_id"], name: "index_miembro_estado_cambios_on_registrado_por_id"
  end

  create_table "miembro_familiares", force: :cascade do |t|
    t.bigint "miembro_id", null: false
    t.string "nombre_completo", null: false
    t.string "parentesco", null: false
    t.date "fecha_nacimiento"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["miembro_id"], name: "index_miembro_familiares_on_miembro_id"
  end

  create_table "miembros", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "logia_id", null: false
    t.string "numero_miembro", null: false
    t.string "cedula", null: false
    t.string "grado"
    t.integer "estado", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "estado_desde"
    t.date "estado_hasta"
    t.string "estado_motivo"
    t.date "fecha_ingreso"
    t.jsonb "aliases", default: [], null: false
    t.index ["cedula"], name: "index_miembros_on_cedula", unique: true
    t.index ["estado"], name: "index_miembros_on_estado"
    t.index ["logia_id"], name: "index_miembros_on_logia_id"
    t.index ["numero_miembro"], name: "index_miembros_on_numero_miembro", unique: true
    t.index ["user_id"], name: "index_miembros_on_user_id"
  end

  create_table "negocio_anuncios", force: :cascade do |t|
    t.string "titulo", null: false
    t.text "descripcion"
    t.string "tipo", default: "servicio", null: false
    t.string "categoria"
    t.decimal "precio", precision: 12, scale: 2
    t.string "moneda", default: "COP"
    t.string "contacto"
    t.string "ubicacion"
    t.boolean "activo", default: true, null: false
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "estado", default: "disponible", null: false
    t.integer "vistas_count", default: 0, null: false
    t.string "slug"
    t.decimal "latitud", precision: 10, scale: 6
    t.decimal "longitud", precision: 10, scale: 6
    t.index ["estado"], name: "index_negocio_anuncios_on_estado"
    t.index ["logia_id", "activo"], name: "index_negocio_anuncios_on_logia_id_and_activo"
    t.index ["logia_id"], name: "index_negocio_anuncios_on_logia_id"
    t.index ["slug"], name: "index_negocio_anuncios_on_slug", unique: true
    t.index ["tipo"], name: "index_negocio_anuncios_on_tipo"
    t.index ["user_id"], name: "index_negocio_anuncios_on_user_id"
  end

  create_table "negocio_conversacions", force: :cascade do |t|
    t.bigint "negocio_anuncio_id", null: false
    t.integer "comprador_id"
    t.integer "vendedor_id"
    t.datetime "ultimo_mensaje_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comprador_id"], name: "index_negocio_conversacions_on_comprador_id"
    t.index ["negocio_anuncio_id", "comprador_id"], name: "idx_neg_conv_anuncio_comp", unique: true
    t.index ["negocio_anuncio_id"], name: "index_negocio_conversacions_on_negocio_anuncio_id"
    t.index ["vendedor_id"], name: "index_negocio_conversacions_on_vendedor_id"
  end

  create_table "negocio_favoritos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "negocio_anuncio_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["negocio_anuncio_id"], name: "index_negocio_favoritos_on_negocio_anuncio_id"
    t.index ["user_id", "negocio_anuncio_id"], name: "idx_neg_fav_user_anuncio", unique: true
    t.index ["user_id"], name: "index_negocio_favoritos_on_user_id"
  end

  create_table "negocio_mensajes", force: :cascade do |t|
    t.bigint "negocio_conversacion_id", null: false
    t.bigint "user_id", null: false
    t.text "cuerpo"
    t.boolean "leido", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["negocio_conversacion_id"], name: "index_negocio_mensajes_on_negocio_conversacion_id"
    t.index ["user_id"], name: "index_negocio_mensajes_on_user_id"
  end

  create_table "negocio_reportes", force: :cascade do |t|
    t.bigint "negocio_anuncio_id", null: false
    t.bigint "user_id", null: false
    t.string "motivo"
    t.text "descripcion"
    t.boolean "resuelto", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["negocio_anuncio_id"], name: "index_negocio_reportes_on_negocio_anuncio_id"
    t.index ["user_id"], name: "index_negocio_reportes_on_user_id"
  end

  create_table "pagos", force: :cascade do |t|
    t.bigint "cobro_id", null: false
    t.string "numero_rc"
    t.decimal "monto_pagado", precision: 10, scale: 2, null: false
    t.date "fecha_pago", null: false
    t.string "metodo_pago", default: "transferencia", null: false
    t.text "observaciones"
    t.bigint "validado_por_id"
    t.datetime "validado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "datos_ocr"
    t.decimal "descuento_porcentaje", precision: 5, scale: 2, default: "0.0"
    t.decimal "descuento_monto", precision: 10, scale: 2, default: "0.0"
    t.index ["cobro_id"], name: "index_pagos_on_cobro_id"
    t.index ["numero_rc"], name: "index_pagos_on_numero_rc"
    t.index ["validado_por_id"], name: "index_pagos_on_validado_por_id"
  end

  create_table "periodo_cobros", force: :cascade do |t|
    t.string "nombre", null: false
    t.integer "anio", null: false
    t.integer "mes", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.date "fecha_vencimiento", null: false
    t.integer "estado", default: 0, null: false
    t.bigint "creado_por_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["anio", "mes"], name: "index_periodo_cobros_on_anio_and_mes", unique: true
    t.index ["creado_por_id"], name: "index_periodo_cobros_on_creado_por_id"
  end

  create_table "permisos", force: :cascade do |t|
    t.string "recurso", null: false
    t.string "accion", null: false
    t.string "descripcion"
    t.datetime "created_at", null: false
    t.index ["recurso", "accion"], name: "index_permisos_on_recurso_and_accion", unique: true
  end

  create_table "rol_permisos", force: :cascade do |t|
    t.bigint "rol_id", null: false
    t.bigint "permiso_id", null: false
    t.index ["rol_id", "permiso_id"], name: "index_rol_permisos_on_rol_id_and_permiso_id", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "codigo", null: false
    t.string "descripcion"
    t.boolean "es_sistema", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "logia_id"
    t.index ["codigo"], name: "index_roles_on_codigo", unique: true
    t.index ["logia_id"], name: "index_roles_on_logia_id"
    t.index ["nombre"], name: "index_roles_on_nombre", unique: true
  end

  create_table "tarifas", force: :cascade do |t|
    t.bigint "logia_id", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.date "vigente_desde", null: false
    t.date "vigente_hasta", null: false
    t.jsonb "desglose", default: []
    t.bigint "creado_por_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creado_por_id"], name: "index_tarifas_on_creado_por_id"
    t.index ["logia_id", "vigente_desde"], name: "index_tarifas_on_logia_id_and_vigente_desde"
    t.index ["logia_id"], name: "index_tarifas_on_logia_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "nombre", default: "", null: false
    t.string "apellido", default: "", null: false
    t.integer "rol", default: 0, null: false
    t.bigint "logia_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "rol_ref_id"
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["logia_id"], name: "index_users_on_logia_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["rol"], name: "index_users_on_rol"
    t.index ["rol_ref_id"], name: "index_users_on_rol_ref_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "calendario_eventos", "logias"
  add_foreign_key "calendario_eventos", "users"
  add_foreign_key "calendario_sincronizaciones", "logias", column: "logia_destino_id"
  add_foreign_key "calendario_sincronizaciones", "logias", column: "logia_solicitante_id"
  add_foreign_key "calendario_sincronizaciones", "users", column: "solicitado_por_id"
  add_foreign_key "cargos", "logias"
  add_foreign_key "chat_mensajes", "logias"
  add_foreign_key "chat_mensajes", "users"
  add_foreign_key "cobros", "miembros"
  add_foreign_key "cobros", "periodo_cobros"
  add_foreign_key "conceptos_cobros", "logias"
  add_foreign_key "corte_conciliaciones", "logias"
  add_foreign_key "corte_conciliaciones", "users", column: "creado_por_id"
  add_foreign_key "logias", "logias", column: "tenant_id"
  add_foreign_key "miembro_cargos", "cargos"
  add_foreign_key "miembro_cargos", "miembros"
  add_foreign_key "miembro_cargos", "users", column: "asignado_por_id"
  add_foreign_key "miembro_estado_cambios", "miembros"
  add_foreign_key "miembro_estado_cambios", "users", column: "registrado_por_id"
  add_foreign_key "miembros", "logias"
  add_foreign_key "miembros", "users"
  add_foreign_key "negocio_conversacions", "negocio_anuncios"
  add_foreign_key "negocio_favoritos", "negocio_anuncios"
  add_foreign_key "negocio_favoritos", "users"
  add_foreign_key "negocio_mensajes", "negocio_conversacions"
  add_foreign_key "negocio_mensajes", "users"
  add_foreign_key "negocio_reportes", "negocio_anuncios"
  add_foreign_key "negocio_reportes", "users"
  add_foreign_key "pagos", "cobros"
  add_foreign_key "pagos", "users", column: "validado_por_id"
  add_foreign_key "periodo_cobros", "users", column: "creado_por_id"
  add_foreign_key "rol_permisos", "permisos"
  add_foreign_key "rol_permisos", "roles", column: "rol_id"
  add_foreign_key "roles", "logias"
  add_foreign_key "tarifas", "logias"
  add_foreign_key "tarifas", "users", column: "creado_por_id"
  add_foreign_key "users", "logias"
  add_foreign_key "users", "roles", column: "rol_ref_id"
end
