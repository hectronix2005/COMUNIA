# DENUNCIAPP dentro de COMUNIA. Reglas (traspaso, sección 1):
# - Ninguna FK ni columna que enlace con users, miembros ni logias. La única relación con una
#   persona es reportes.cuenta_id → la cuenta de ALIAS (que no es un miembro de COMUNIA).
# - Sin t.timestamps: las horas se guardan redondeadas a la hora, a mano.
# - Sin columnas de IP ni user-agent.
# - pases_usados: solo el sha256 del msg, como clave primaria y nada más.
# - eventos_custodia es de solo inserción (triggers).
class CreateDenuncias < ActiveRecord::Migration[8.1]
  def up
    create_table :denuncias_reportes, id: :string do |t|
      t.bigserial :n, null: false, index: { unique: true } # orden del muro y paginación (antes=n)
      t.string  :categoria, null: false
      t.string  :estado, null: false # publicado | oculto | retirado
      t.string  :titulo, null: false
      t.text    :descripcion, null: false
      t.string  :localidad, null: false
      t.string  :lugar, null: false
      t.string  :recompensa_id
      t.string  :cuenta_id # solo si el autor publicó con su alias
      t.string  :codigo_hash, null: false, index: { unique: true }
      t.text    :texto_original_cif
      t.boolean :verificada, null: false, default: false
      t.boolean :sello_publico, null: false, default: false
      t.datetime :creado_en, null: false # redondeado a la hora
    end
    add_index :denuncias_reportes, [:estado, :n]
    add_index :denuncias_reportes, :cuenta_id

    create_table :denuncias_evidencias, id: :string do |t|
      t.string  :reporte_id, null: false, index: true
      t.integer :orden, null: false
      t.string  :sha256_original, null: false
      t.string  :mime, null: false
      t.integer :bytes, null: false
      t.string  :clave_original, null: false
      t.string  :clave_publica # NULL cuando se retira
      t.text    :metadatos_cif
      t.datetime :creado_en, null: false
    end

    create_table :denuncias_eventos_custodia, id: false do |t|
      t.bigserial :n, primary_key: true
      t.string :reporte_id, null: false
      t.string :evidencia_id
      t.string :tipo, null: false
      t.text   :detalle_json, null: false # TEXTO: el hash va sobre este texto exacto
      t.string :hash_prev, null: false
      t.string :hash_evento, null: false
      t.string :creado_en, null: false # ISO 8601 redondeado, como texto por la misma razón
    end
    add_index :denuncias_eventos_custodia, [:reporte_id, :n]
    execute <<~SQL
      CREATE FUNCTION denuncias_custodia_solo_insercion() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'denuncias_eventos_custodia es solo de inserción';
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER denuncias_custodia_sin_cambios
        BEFORE UPDATE OR DELETE ON denuncias_eventos_custodia
        FOR EACH ROW EXECUTE FUNCTION denuncias_custodia_solo_insercion();
      CREATE TRIGGER denuncias_custodia_sin_truncate
        BEFORE TRUNCATE ON denuncias_eventos_custodia
        FOR EACH STATEMENT EXECUTE FUNCTION denuncias_custodia_solo_insercion();
    SQL

    create_table :denuncias_solicitudes_retiro, id: :string do |t|
      t.string :reporte_id, null: false, index: true
      t.text   :motivo, null: false
      t.text   :contacto_cif
      t.string :estado, null: false # pendiente | aceptada | rechazada
      t.datetime :creado_en, null: false
    end

    create_table :denuncias_cuentas, id: :string do |t|
      t.string :alias, index: { unique: true } # se elige una vez y no cambia
      t.string :email_hash, null: false, index: { unique: true } # HMAC del correo
      t.text   :email_cif, null: false
      t.datetime :email_verificado
      t.datetime :current_sign_in_at # para que cada enlace sirva una sola vez
      t.datetime :creado_en, null: false
    end

    create_table :denuncias_remisiones, id: :string do |t|
      t.string :reporte_id, null: false, index: true
      t.string :entidad, null: false
      t.string :paquete_sha256, null: false
      t.datetime :creado_en, null: false
    end

    create_table :denuncias_pases_usados, id: false do |t|
      t.string :sha256, primary_key: true
    end

    create_table :denuncias_recompensas, id: :string do |t|
      t.string :titulo, null: false
      t.string :entidad, null: false
      t.string :monto_texto, null: false
      t.string :fuente_url, null: false
      t.date   :vigente_hasta
      t.string :estado, null: false # publicada | vencida
      t.datetime :creado_en, null: false
    end
  end

  def down
    execute "DROP TRIGGER IF EXISTS denuncias_custodia_sin_cambios ON denuncias_eventos_custodia"
    execute "DROP TRIGGER IF EXISTS denuncias_custodia_sin_truncate ON denuncias_eventos_custodia"
    %i[denuncias_recompensas denuncias_pases_usados denuncias_remisiones denuncias_cuentas
       denuncias_solicitudes_retiro denuncias_eventos_custodia denuncias_evidencias denuncias_reportes].each { drop_table _1 }
    execute "DROP FUNCTION IF EXISTS denuncias_custodia_solo_insercion()"
  end
end
