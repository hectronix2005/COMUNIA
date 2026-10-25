# Red social de comunidades certificadas (piloto del 24-oct-2026). Diseño y reglas de privacidad en
# app/models/red.rb y NOTAS.md. Ninguna tabla guarda la lista de comunidades de una persona en otro
# sitio que no sea red_membresias, y ninguna vista pública lee esa tabla: lee red_confianzas.
class CreateRed < ActiveRecord::Migration[8.1]
  def change
    # Cuentas que solo usan la red (sin logia): el resto de COMUNIA les está cerrado.
    add_column :users, :solo_red, :boolean, default: false, null: false

    create_table :red_comunidades do |t|
      t.string :token, null: false
      t.string :nombre, null: false
      t.string :tipo_vinculo, null: false
      t.text :criterio, null: false # qué tienen en común, y es comprobable
      t.text :descripcion
      t.string :ciudad
      t.text :evidencia # de que la comunidad existe (sitio oficial, NIT, resolución…)
      t.string :metodo_verificacion, null: false, default: "documento"
      t.string :dominio_correo
      t.string :estado, null: false, default: "solicitada"
      t.text :motivo_estado
      t.datetime :certificada_at
      t.references :solicitada_por, foreign_key: { to_table: :users }
      t.references :revisada_por, foreign_key: { to_table: :users }
      t.references :logia, foreign_key: true, index: { unique: true }
      t.integer :miembros_count, null: false, default: 0
      t.integer :tamano_publico, null: false, default: 0 # foto diaria: lo que se enseña, en banda
      t.timestamps
      t.index :token, unique: true
      t.index :estado
    end

    create_table :red_membresias do |t|
      t.references :comunidad, null: false, foreign_key: { to_table: :red_comunidades }
      t.references :user, null: false, foreign_key: true
      t.string :estado, null: false, default: "solicitada"
      t.string :rol, null: false, default: "miembro"
      t.text :evidencia
      t.references :verificada_por, foreign_key: { to_table: :users }
      t.datetime :verificada_at
      t.date :vence_el
      t.text :motivo
      t.timestamps
      t.index [:comunidad_id, :user_id], unique: true
      t.index [:comunidad_id, :estado]
      t.index [:user_id, :estado]
    end

    create_table :red_perfiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false
      t.string :nombre_publico, null: false
      t.string :titular
      t.text :bio
      t.string :ciudad
      t.text :habilidades
      t.string :alcance, null: false, default: "mis_comunidades"
      t.boolean :visible_publico, null: false, default: false
      t.string :contacto_telefono
      t.string :contacto_correo
      t.datetime :acepto_tratamiento_at, null: false
      t.string :politica_version, null: false
      t.datetime :cuarentena_hasta, null: false
      t.integer :sanciones, null: false, default: 0
      t.datetime :suspendido_at
      t.datetime :onboarding_completado_at
      t.timestamps
      t.index :token, unique: true
    end

    create_table :red_publicaciones do |t|
      t.string :token, null: false
      t.references :user, null: false, foreign_key: true
      t.string :intencion, null: false # necesito | ofrezco
      t.string :categoria, null: false
      t.string :titulo, null: false
      t.text :descripcion, null: false
      t.string :ciudad
      t.string :modalidad, null: false, default: "presencial"
      t.string :precio_texto
      t.string :estado, null: false, default: "activa"
      t.string :motivo_revision
      t.string :alcance, null: false, default: "mis_comunidades"
      t.datetime :publica_desde, null: false # la cuarentena retrasa la búsqueda sin cuenta
      t.date :vence_el, null: false
      t.integer :reportes_count, null: false, default: 0
      t.timestamps
      t.index :token, unique: true
      t.index [:estado, :alcance, :created_at]
      t.index [:user_id, :estado]
    end

    # Comunidades concretas elegidas por la persona (alcance «elegidas») para su perfil o una publicación.
    create_table :red_alcances do |t|
      t.references :objeto, polymorphic: true, null: false
      t.references :comunidad, null: false, foreign_key: { to_table: :red_comunidades }
      t.index [:objeto_type, :objeto_id, :comunidad_id], unique: true, name: "index_red_alcances_unicos"
    end

    # Foto diaria de la confianza: es lo único que se enseña hacia fuera. El puntaje no sale nunca.
    create_table :red_confianzas do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.decimal :puntaje, precision: 8, scale: 4, null: false, default: 0
      t.integer :nivel, null: false, default: 0
      t.integer :comunidades, null: false, default: 0
      t.string :banda_miembros, null: false, default: "ninguno"
      t.datetime :calculada_at, null: false
    end

    create_table :red_conversaciones do |t|
      t.string :token, null: false
      t.references :publicacion, foreign_key: { to_table: :red_publicaciones }
      t.references :iniciador, foreign_key: { to_table: :users } # nil: quien busca sin cuenta
      t.references :destinatario, null: false, foreign_key: { to_table: :users }
      t.string :nombre_externo
      t.text :contacto_externo_cif
      t.string :estado, null: false, default: "abierta"
      t.datetime :ultimo_mensaje_at
      t.timestamps
      t.index :token, unique: true
      t.index [:iniciador_id, :destinatario_id, :publicacion_id], unique: true, name: "index_red_conversaciones_unicas"
    end

    create_table :red_mensajes do |t|
      t.references :conversacion, null: false, foreign_key: { to_table: :red_conversaciones }
      t.references :user, foreign_key: true # nil: externo o sistema
      t.string :tipo, null: false, default: "texto"
      t.text :cuerpo, null: false
      t.datetime :leido_at
      t.timestamps
    end

    create_table :red_resenas do |t|
      t.references :conversacion, null: false, foreign_key: { to_table: :red_conversaciones }
      t.references :autor, null: false, foreign_key: { to_table: :users }
      t.references :sujeto, null: false, foreign_key: { to_table: :users }
      t.integer :puntaje, null: false
      t.text :comentario
      t.text :respuesta
      t.timestamps
      t.index [:conversacion_id, :autor_id], unique: true
    end

    create_table :red_reportes do |t|
      t.references :objeto, polymorphic: true, null: false
      t.references :reportante, foreign_key: { to_table: :users }
      t.string :huella, null: false # usuario o HMAC de la IP: un voto por persona
      t.string :motivo, null: false
      t.text :detalle
      t.string :estado, null: false, default: "pendiente"
      t.references :resuelto_por, foreign_key: { to_table: :users }
      t.datetime :resuelto_at
      t.timestamps
      t.index [:objeto_type, :objeto_id, :huella], unique: true, name: "index_red_reportes_un_voto"
      t.index :estado
    end

    create_table :red_bloqueos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bloqueado, null: false, foreign_key: { to_table: :users }
      t.timestamps
      t.index [:user_id, :bloqueado_id], unique: true
    end

    create_table :red_busquedas_diarias do |t|
      t.date :fecha, null: false
      t.integer :con_cuenta, null: false, default: 0
      t.integer :sin_cuenta, null: false, default: 0
      t.index :fecha, unique: true
    end
  end
end
