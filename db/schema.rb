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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_030000) do
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
    t.datetime "recordatorio_enviado_at"
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

  create_table "categorias", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "icono"
    t.string "termino_miembro"
    t.string "termino_logia"
    t.string "termino_cobro"
    t.string "termino_reunion"
    t.string "termino_ayuda"
    t.string "termino_documentos"
    t.string "modulos", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((nombre)::text)", name: "index_categorias_on_lower_nombre", unique: true
  end

  create_table "chat_mensajes", force: :cascade do |t|
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.text "contenido"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "destinatario_id"
    t.string "canal", default: "logia", null: false
    t.datetime "leido_at"
    t.jsonb "reacciones", default: {}, null: false
    t.index ["canal"], name: "index_chat_mensajes_on_canal"
    t.index ["destinatario_id", "leido_at"], name: "index_chat_mensajes_unread_dm", where: "(((canal)::text = 'dm'::text) AND (leido_at IS NULL))"
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
    t.index ["logia_id", "nombre"], name: "index_conceptos_cobros_on_logia_id_and_nombre", unique: true
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

  create_table "denuncias_eventos_custodia", primary_key: "n", force: :cascade do |t|
    t.string "reporte_id", null: false
    t.string "evidencia_id"
    t.string "tipo", null: false
    t.text "detalle_json", null: false
    t.string "hash_prev", null: false
    t.string "hash_evento", null: false
    t.string "creado_en", null: false
    t.index ["reporte_id", "n"], name: "index_denuncias_eventos_custodia_on_reporte_id_and_n"
  end

  create_table "denuncias_evidencias", id: :string, force: :cascade do |t|
    t.string "reporte_id", null: false
    t.integer "orden", null: false
    t.string "sha256_original", null: false
    t.string "mime", null: false
    t.integer "bytes", null: false
    t.string "clave_original", null: false
    t.string "clave_publica"
    t.text "metadatos_cif"
    t.datetime "creado_en", null: false
    t.index ["reporte_id"], name: "index_denuncias_evidencias_on_reporte_id"
  end

  create_table "denuncias_recompensas", id: :string, force: :cascade do |t|
    t.string "titulo", null: false
    t.string "entidad", null: false
    t.string "monto_texto", null: false
    t.string "fuente_url", null: false
    t.date "vigente_hasta"
    t.string "estado", null: false
    t.datetime "creado_en", null: false
  end

  create_table "denuncias_remisiones", id: :string, force: :cascade do |t|
    t.string "reporte_id", null: false
    t.string "entidad", null: false
    t.string "paquete_sha256", null: false
    t.datetime "creado_en", null: false
    t.index ["reporte_id"], name: "index_denuncias_remisiones_on_reporte_id"
  end

  create_table "denuncias_reportes", id: :string, force: :cascade do |t|
    t.bigserial "n", null: false
    t.string "categoria", null: false
    t.string "estado", null: false
    t.string "titulo", null: false
    t.text "descripcion", null: false
    t.string "localidad", null: false
    t.string "lugar", null: false
    t.string "recompensa_id"
    t.text "texto_original_cif"
    t.boolean "verificada", default: false, null: false
    t.datetime "creado_en", null: false
    t.bigint "user_id"
    t.index ["estado", "n"], name: "index_denuncias_reportes_on_estado_and_n"
    t.index ["n"], name: "index_denuncias_reportes_on_n", unique: true
    t.index ["user_id"], name: "index_denuncias_reportes_on_user_id"
  end

  create_table "denuncias_solicitudes_retiro", id: :string, force: :cascade do |t|
    t.string "reporte_id", null: false
    t.text "motivo", null: false
    t.text "contacto_cif"
    t.string "estado", null: false
    t.datetime "creado_en", null: false
    t.index ["reporte_id"], name: "index_denuncias_solicitudes_retiro_on_reporte_id"
  end

  create_table "encuesta_opciones", force: :cascade do |t|
    t.bigint "encuesta_id", null: false
    t.string "texto", null: false
    t.integer "posicion", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encuesta_id"], name: "index_encuesta_opciones_on_encuesta_id"
  end

  create_table "encuesta_votos", force: :cascade do |t|
    t.bigint "encuesta_opcion_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encuesta_opcion_id", "user_id"], name: "idx_encuesta_voto_opcion_user", unique: true
    t.index ["encuesta_opcion_id"], name: "index_encuesta_votos_on_encuesta_opcion_id"
    t.index ["user_id"], name: "index_encuesta_votos_on_user_id"
  end

  create_table "encuestas", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "logia_id", null: false
    t.string "titulo", null: false
    t.text "descripcion"
    t.boolean "anonima", default: false, null: false
    t.boolean "multiple", default: false, null: false
    t.integer "estado", default: 0, null: false
    t.datetime "cierre_en"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["logia_id"], name: "index_encuestas_on_logia_id"
    t.index ["user_id"], name: "index_encuestas_on_user_id"
  end

  create_table "errores_app", force: :cascade do |t|
    t.string "huella", null: false
    t.string "clase", null: false
    t.text "mensaje"
    t.string "ubicacion"
    t.string "origen"
    t.text "traza"
    t.integer "veces", default: 1, null: false
    t.datetime "primera_vez", null: false
    t.datetime "ultima_vez", null: false
    t.datetime "resuelto_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["huella"], name: "index_errores_app_on_huella", unique: true
    t.index ["ultima_vez"], name: "index_errores_app_on_ultima_vez"
  end

  create_table "evento_confirmaciones", force: :cascade do |t|
    t.bigint "calendario_evento_id", null: false
    t.bigint "user_id", null: false
    t.integer "estado", default: 0, null: false
    t.text "nota"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendario_evento_id", "user_id"], name: "idx_evento_conf_evento_user", unique: true
    t.index ["calendario_evento_id"], name: "index_evento_confirmaciones_on_calendario_evento_id"
    t.index ["user_id"], name: "index_evento_confirmaciones_on_user_id"
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
    t.bigint "categoria_id"
    t.index ["categoria_id"], name: "index_logias_on_categoria_id"
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
    t.string "profesion"
    t.string "empresa"
    t.string "telefono"
    t.text "habilidades"
    t.date "fecha_iniciacion"
    t.text "bio"
    t.index ["cedula"], name: "index_miembros_on_cedula", unique: true
    t.index ["estado"], name: "index_miembros_on_estado"
    t.index ["logia_id"], name: "index_miembros_on_logia_id"
    t.index ["numero_miembro"], name: "index_miembros_on_numero_miembro", unique: true
    t.index ["user_id"], name: "index_miembros_on_user_id", unique: true
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
    t.index ["negocio_anuncio_id", "user_id"], name: "index_negocio_reportes_on_negocio_anuncio_id_and_user_id", unique: true
    t.index ["negocio_anuncio_id"], name: "index_negocio_reportes_on_negocio_anuncio_id"
    t.index ["user_id"], name: "index_negocio_reportes_on_user_id"
  end

  create_table "notificaciones", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "logia_id"
    t.string "tipo", null: false
    t.string "titulo", null: false
    t.text "cuerpo"
    t.string "url"
    t.boolean "leida", default: false, null: false
    t.datetime "leida_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["logia_id"], name: "index_notificaciones_on_logia_id"
    t.index ["user_id", "leida", "created_at"], name: "index_notificaciones_on_user_id_and_leida_and_created_at", order: { created_at: :desc }
    t.index ["user_id"], name: "index_notificaciones_on_user_id"
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
    t.bigint "tenant_id", null: false
    t.index ["creado_por_id"], name: "index_periodo_cobros_on_creado_por_id"
    t.index ["tenant_id", "anio", "mes"], name: "index_periodo_cobros_on_tenant_id_and_anio_and_mes", unique: true
  end

  create_table "permisos", force: :cascade do |t|
    t.string "recurso", null: false
    t.string "accion", null: false
    t.string "descripcion"
    t.datetime "created_at", null: false
    t.index ["recurso", "accion"], name: "index_permisos_on_recurso_and_accion", unique: true
  end

  create_table "publicacion_comentarios", force: :cascade do |t|
    t.bigint "publicacion_id", null: false
    t.bigint "user_id", null: false
    t.text "contenido", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publicacion_id"], name: "index_publicacion_comentarios_on_publicacion_id"
    t.index ["user_id"], name: "index_publicacion_comentarios_on_user_id"
  end

  create_table "publicacion_likes", force: :cascade do |t|
    t.bigint "publicacion_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publicacion_id", "user_id"], name: "idx_pub_like_pub_user", unique: true
    t.index ["publicacion_id"], name: "index_publicacion_likes_on_publicacion_id"
    t.index ["user_id"], name: "index_publicacion_likes_on_user_id"
  end

  create_table "publicaciones", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "logia_id", null: false
    t.text "contenido", null: false
    t.boolean "fijada", default: false, null: false
    t.integer "likes_count", default: 0, null: false
    t.integer "comentarios_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["logia_id", "created_at"], name: "index_publicaciones_on_logia_id_and_created_at", order: { created_at: :desc }
    t.index ["logia_id"], name: "index_publicaciones_on_logia_id"
    t.index ["user_id"], name: "index_publicaciones_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "endpoint", null: false
    t.text "p256dh", null: false
    t.text "auth", null: false
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "red_alcances", force: :cascade do |t|
    t.string "objeto_type", null: false
    t.bigint "objeto_id", null: false
    t.bigint "comunidad_id", null: false
    t.index ["comunidad_id"], name: "index_red_alcances_on_comunidad_id"
    t.index ["objeto_type", "objeto_id", "comunidad_id"], name: "index_red_alcances_unicos", unique: true
    t.index ["objeto_type", "objeto_id"], name: "index_red_alcances_on_objeto"
  end

  create_table "red_bloqueos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "bloqueado_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bloqueado_id"], name: "index_red_bloqueos_on_bloqueado_id"
    t.index ["user_id", "bloqueado_id"], name: "index_red_bloqueos_on_user_id_and_bloqueado_id", unique: true
    t.index ["user_id"], name: "index_red_bloqueos_on_user_id"
  end

  create_table "red_busquedas_diarias", force: :cascade do |t|
    t.date "fecha", null: false
    t.integer "con_cuenta", default: 0, null: false
    t.integer "sin_cuenta", default: 0, null: false
    t.index ["fecha"], name: "index_red_busquedas_diarias_on_fecha", unique: true
  end

  create_table "red_comunidades", force: :cascade do |t|
    t.string "token", null: false
    t.string "nombre", null: false
    t.string "tipo_vinculo", null: false
    t.text "criterio", null: false
    t.text "descripcion"
    t.string "ciudad"
    t.text "evidencia"
    t.string "metodo_verificacion", default: "documento", null: false
    t.string "dominio_correo"
    t.string "estado", default: "solicitada", null: false
    t.text "motivo_estado"
    t.datetime "certificada_at"
    t.bigint "solicitada_por_id"
    t.bigint "revisada_por_id"
    t.bigint "logia_id"
    t.integer "miembros_count", default: 0, null: false
    t.integer "tamano_publico", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((nombre)::text)", name: "index_red_comunidades_on_lower_nombre", unique: true
    t.index ["estado"], name: "index_red_comunidades_on_estado"
    t.index ["logia_id"], name: "index_red_comunidades_on_logia_id", unique: true
    t.index ["revisada_por_id"], name: "index_red_comunidades_on_revisada_por_id"
    t.index ["solicitada_por_id"], name: "index_red_comunidades_on_solicitada_por_id"
    t.index ["token"], name: "index_red_comunidades_on_token", unique: true
  end

  create_table "red_confianzas", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "puntaje", precision: 8, scale: 4, default: "0.0", null: false
    t.integer "nivel", default: 0, null: false
    t.integer "comunidades", default: 0, null: false
    t.string "banda_miembros", default: "ninguno", null: false
    t.datetime "calculada_at", null: false
    t.index ["user_id"], name: "index_red_confianzas_on_user_id", unique: true
  end

  create_table "red_conversaciones", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "publicacion_id"
    t.bigint "iniciador_id"
    t.bigint "destinatario_id", null: false
    t.string "nombre_externo"
    t.text "contacto_externo_cif"
    t.string "estado", default: "abierta", null: false
    t.datetime "ultimo_mensaje_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["destinatario_id"], name: "index_red_conversaciones_on_destinatario_id"
    t.index ["iniciador_id", "destinatario_id", "publicacion_id"], name: "index_red_conversaciones_unicas", unique: true
    t.index ["iniciador_id"], name: "index_red_conversaciones_on_iniciador_id"
    t.index ["publicacion_id"], name: "index_red_conversaciones_on_publicacion_id"
    t.index ["token"], name: "index_red_conversaciones_on_token", unique: true
  end

  create_table "red_membresias", force: :cascade do |t|
    t.bigint "comunidad_id", null: false
    t.bigint "user_id", null: false
    t.string "estado", default: "solicitada", null: false
    t.string "rol", default: "miembro", null: false
    t.text "evidencia"
    t.bigint "verificada_por_id"
    t.datetime "verificada_at"
    t.date "vence_el"
    t.text "motivo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comunidad_id", "estado"], name: "index_red_membresias_on_comunidad_id_and_estado"
    t.index ["comunidad_id", "user_id"], name: "index_red_membresias_on_comunidad_id_and_user_id", unique: true
    t.index ["comunidad_id"], name: "index_red_membresias_on_comunidad_id"
    t.index ["user_id", "estado"], name: "index_red_membresias_on_user_id_and_estado"
    t.index ["user_id"], name: "index_red_membresias_on_user_id"
    t.index ["verificada_por_id"], name: "index_red_membresias_on_verificada_por_id"
  end

  create_table "red_mensajes", force: :cascade do |t|
    t.bigint "conversacion_id", null: false
    t.bigint "user_id"
    t.string "tipo", default: "texto", null: false
    t.text "cuerpo", null: false
    t.datetime "leido_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversacion_id"], name: "index_red_mensajes_on_conversacion_id"
    t.index ["user_id"], name: "index_red_mensajes_on_user_id"
  end

  create_table "red_perfiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "nombre_publico", null: false
    t.string "titular"
    t.text "bio"
    t.string "ciudad"
    t.text "habilidades"
    t.string "alcance", default: "mis_comunidades", null: false
    t.boolean "visible_publico", default: false, null: false
    t.string "contacto_telefono"
    t.string "contacto_correo"
    t.datetime "acepto_tratamiento_at", null: false
    t.string "politica_version", null: false
    t.datetime "cuarentena_hasta", null: false
    t.integer "sanciones", default: 0, null: false
    t.datetime "suspendido_at"
    t.datetime "onboarding_completado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_red_perfiles_on_token", unique: true
    t.index ["user_id"], name: "index_red_perfiles_on_user_id", unique: true
  end

  create_table "red_publicaciones", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "user_id", null: false
    t.string "intencion", null: false
    t.string "categoria", null: false
    t.string "titulo", null: false
    t.text "descripcion", null: false
    t.string "ciudad"
    t.string "modalidad", default: "presencial", null: false
    t.string "precio_texto"
    t.string "estado", default: "activa", null: false
    t.string "motivo_revision"
    t.string "alcance", default: "mis_comunidades", null: false
    t.datetime "publica_desde", null: false
    t.date "vence_el", null: false
    t.integer "reportes_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["estado", "alcance", "created_at"], name: "index_red_publicaciones_on_estado_and_alcance_and_created_at"
    t.index ["token"], name: "index_red_publicaciones_on_token", unique: true
    t.index ["user_id", "estado"], name: "index_red_publicaciones_on_user_id_and_estado"
    t.index ["user_id"], name: "index_red_publicaciones_on_user_id"
  end

  create_table "red_reportes", force: :cascade do |t|
    t.string "objeto_type", null: false
    t.bigint "objeto_id", null: false
    t.bigint "reportante_id"
    t.string "huella", null: false
    t.string "motivo", null: false
    t.text "detalle"
    t.string "estado", default: "pendiente", null: false
    t.bigint "resuelto_por_id"
    t.datetime "resuelto_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["estado"], name: "index_red_reportes_on_estado"
    t.index ["objeto_type", "objeto_id", "huella"], name: "index_red_reportes_un_voto", unique: true
    t.index ["objeto_type", "objeto_id"], name: "index_red_reportes_on_objeto"
    t.index ["reportante_id"], name: "index_red_reportes_on_reportante_id"
    t.index ["resuelto_por_id"], name: "index_red_reportes_on_resuelto_por_id"
  end

  create_table "red_resenas", force: :cascade do |t|
    t.bigint "conversacion_id", null: false
    t.bigint "autor_id", null: false
    t.bigint "sujeto_id", null: false
    t.integer "puntaje", null: false
    t.text "comentario"
    t.text "respuesta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["autor_id"], name: "index_red_resenas_on_autor_id"
    t.index ["conversacion_id", "autor_id"], name: "index_red_resenas_on_conversacion_id_and_autor_id", unique: true
    t.index ["conversacion_id"], name: "index_red_resenas_on_conversacion_id"
    t.index ["sujeto_id"], name: "index_red_resenas_on_sujeto_id"
  end

  create_table "reunion_acuerdos", force: :cascade do |t|
    t.bigint "reunion_id", null: false
    t.bigint "responsable_id"
    t.string "texto", null: false
    t.date "vence_el"
    t.datetime "cumplido_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "recordatorio_enviado_at"
    t.index ["responsable_id", "cumplido_at"], name: "index_reunion_acuerdos_on_responsable_id_and_cumplido_at"
    t.index ["reunion_id"], name: "index_reunion_acuerdos_on_reunion_id"
  end

  create_table "reunion_asistencias", force: :cascade do |t|
    t.bigint "reunion_id", null: false
    t.bigint "miembro_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["miembro_id"], name: "index_reunion_asistencias_on_miembro_id"
    t.index ["reunion_id", "miembro_id"], name: "index_reunion_asistencias_on_reunion_id_and_miembro_id", unique: true
    t.index ["reunion_id"], name: "index_reunion_asistencias_on_reunion_id"
  end

  create_table "reunion_propuestas", force: :cascade do |t|
    t.bigint "reunion_id", null: false
    t.bigint "miembro_id", null: false
    t.string "texto", null: false
    t.integer "estado", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["miembro_id"], name: "index_reunion_propuestas_on_miembro_id"
    t.index ["reunion_id", "estado"], name: "index_reunion_propuestas_on_reunion_id_and_estado"
  end

  create_table "reunion_votaciones", force: :cascade do |t|
    t.bigint "reunion_id", null: false
    t.bigint "user_id", null: false
    t.string "pregunta", null: false
    t.boolean "secreta", default: true, null: false
    t.integer "estado", default: 0, null: false
    t.datetime "cerrada_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reunion_id"], name: "index_reunion_votaciones_on_reunion_id"
    t.index ["user_id"], name: "index_reunion_votaciones_on_user_id"
  end

  create_table "reunion_votos", force: :cascade do |t|
    t.bigint "reunion_votacion_id", null: false
    t.bigint "miembro_id", null: false
    t.integer "opcion", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["miembro_id"], name: "index_reunion_votos_on_miembro_id"
    t.index ["reunion_votacion_id", "miembro_id"], name: "index_reunion_votos_on_reunion_votacion_id_and_miembro_id", unique: true
    t.index ["reunion_votacion_id"], name: "index_reunion_votos_on_reunion_votacion_id"
  end

  create_table "reuniones", force: :cascade do |t|
    t.bigint "logia_id", null: false
    t.bigint "user_id", null: false
    t.bigint "calendario_evento_id"
    t.string "titulo", null: false
    t.datetime "inicio", null: false
    t.datetime "fin", null: false
    t.string "lugar"
    t.text "orden_del_dia"
    t.integer "estado", default: 0, null: false
    t.text "acta"
    t.datetime "acta_publicada_at"
    t.datetime "recordatorio_enviado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "serie"
    t.string "codigo_asistencia"
    t.datetime "acta_aprobada_at"
    t.bigint "acta_aprobada_en_id"
    t.index ["acta_aprobada_en_id"], name: "index_reuniones_on_acta_aprobada_en_id"
    t.index ["calendario_evento_id"], name: "index_reuniones_on_calendario_evento_id"
    t.index ["codigo_asistencia"], name: "index_reuniones_on_codigo_asistencia", unique: true
    t.index ["logia_id", "inicio"], name: "index_reuniones_on_logia_id_and_inicio"
    t.index ["logia_id"], name: "index_reuniones_on_logia_id"
    t.index ["serie", "inicio"], name: "index_reuniones_on_serie_and_inicio"
    t.index ["user_id"], name: "index_reuniones_on_user_id"
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
    t.string "nombre_visible"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "last_seen_at"
    t.boolean "solo_red", default: false, null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.string "calendario_semilla"
    t.index ["calendario_semilla"], name: "index_users_on_calendario_semilla", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["logia_id"], name: "index_users_on_logia_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["rol"], name: "index_users_on_rol"
    t.index ["rol_ref_id"], name: "index_users_on_rol_ref_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
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
  add_foreign_key "denuncias_reportes", "users", on_delete: :nullify
  add_foreign_key "encuesta_opciones", "encuestas"
  add_foreign_key "encuesta_votos", "encuesta_opciones"
  add_foreign_key "encuesta_votos", "users"
  add_foreign_key "encuestas", "logias"
  add_foreign_key "encuestas", "users"
  add_foreign_key "evento_confirmaciones", "calendario_eventos"
  add_foreign_key "evento_confirmaciones", "users"
  add_foreign_key "logias", "categorias"
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
  add_foreign_key "notificaciones", "logias"
  add_foreign_key "notificaciones", "users"
  add_foreign_key "pagos", "cobros"
  add_foreign_key "pagos", "users", column: "validado_por_id"
  add_foreign_key "periodo_cobros", "logias", column: "tenant_id"
  add_foreign_key "periodo_cobros", "users", column: "creado_por_id"
  add_foreign_key "publicacion_comentarios", "publicaciones"
  add_foreign_key "publicacion_comentarios", "users"
  add_foreign_key "publicacion_likes", "publicaciones"
  add_foreign_key "publicacion_likes", "users"
  add_foreign_key "publicaciones", "logias"
  add_foreign_key "publicaciones", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "red_alcances", "red_comunidades", column: "comunidad_id"
  add_foreign_key "red_bloqueos", "users"
  add_foreign_key "red_bloqueos", "users", column: "bloqueado_id"
  add_foreign_key "red_comunidades", "logias"
  add_foreign_key "red_comunidades", "users", column: "revisada_por_id"
  add_foreign_key "red_comunidades", "users", column: "solicitada_por_id"
  add_foreign_key "red_confianzas", "users"
  add_foreign_key "red_conversaciones", "red_publicaciones", column: "publicacion_id"
  add_foreign_key "red_conversaciones", "users", column: "destinatario_id"
  add_foreign_key "red_conversaciones", "users", column: "iniciador_id"
  add_foreign_key "red_membresias", "red_comunidades", column: "comunidad_id"
  add_foreign_key "red_membresias", "users"
  add_foreign_key "red_membresias", "users", column: "verificada_por_id"
  add_foreign_key "red_mensajes", "red_conversaciones", column: "conversacion_id"
  add_foreign_key "red_mensajes", "users"
  add_foreign_key "red_perfiles", "users"
  add_foreign_key "red_publicaciones", "users"
  add_foreign_key "red_reportes", "users", column: "reportante_id"
  add_foreign_key "red_reportes", "users", column: "resuelto_por_id"
  add_foreign_key "red_resenas", "red_conversaciones", column: "conversacion_id"
  add_foreign_key "red_resenas", "users", column: "autor_id"
  add_foreign_key "red_resenas", "users", column: "sujeto_id"
  add_foreign_key "reunion_acuerdos", "miembros", column: "responsable_id", on_delete: :nullify
  add_foreign_key "reunion_acuerdos", "reuniones", on_delete: :cascade
  add_foreign_key "reunion_asistencias", "miembros"
  add_foreign_key "reunion_asistencias", "reuniones"
  add_foreign_key "reunion_propuestas", "miembros", on_delete: :cascade
  add_foreign_key "reunion_propuestas", "reuniones", on_delete: :cascade
  add_foreign_key "reunion_votaciones", "reuniones"
  add_foreign_key "reunion_votaciones", "users"
  add_foreign_key "reunion_votos", "miembros"
  add_foreign_key "reunion_votos", "reunion_votaciones"
  add_foreign_key "reuniones", "calendario_eventos", on_delete: :nullify
  add_foreign_key "reuniones", "logias"
  add_foreign_key "reuniones", "reuniones", column: "acta_aprobada_en_id", on_delete: :nullify
  add_foreign_key "reuniones", "users"
  add_foreign_key "rol_permisos", "permisos"
  add_foreign_key "rol_permisos", "roles", column: "rol_id"
  add_foreign_key "roles", "logias"
  add_foreign_key "tarifas", "logias"
  add_foreign_key "tarifas", "users", column: "creado_por_id"
  add_foreign_key "users", "logias"
  add_foreign_key "users", "roles", column: "rol_ref_id"
end
