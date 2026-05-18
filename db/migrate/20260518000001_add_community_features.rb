class AddCommunityFeatures < ActiveRecord::Migration[8.0]
  def change
    # ── 1. Directorio: enrich miembros + users ──
    add_column :miembros, :profesion,        :string
    add_column :miembros, :empresa,          :string
    add_column :miembros, :telefono,         :string
    add_column :miembros, :habilidades,      :text
    add_column :miembros, :fecha_iniciacion, :date
    add_column :miembros, :bio,              :text

    # ── 2. Eventos con RSVP ──
    create_table :evento_confirmaciones do |t|
      t.references :calendario_evento, null: false, foreign_key: true
      t.references :user,              null: false, foreign_key: true
      t.integer    :estado,            null: false, default: 0  # 0=pendiente, 1=confirmado, 2=rechazado
      t.text       :nota
      t.timestamps
    end
    add_index :evento_confirmaciones, [:calendario_evento_id, :user_id], unique: true, name: "idx_evento_conf_evento_user"

    # ── 3. Encuestas ──
    create_table :encuestas do |t|
      t.references :user,  null: false, foreign_key: true
      t.references :logia, null: false, foreign_key: true
      t.string     :titulo,    null: false
      t.text       :descripcion
      t.boolean    :anonima,   null: false, default: false
      t.boolean    :multiple,  null: false, default: false
      t.integer    :estado,    null: false, default: 0  # 0=activa, 1=cerrada
      t.datetime   :cierre_en
      t.timestamps
    end

    create_table :encuesta_opciones do |t|
      t.references :encuesta, null: false, foreign_key: true
      t.string     :texto,    null: false
      t.integer    :posicion, null: false, default: 0
      t.timestamps
    end

    create_table :encuesta_votos do |t|
      t.references :encuesta_opcion, null: false, foreign_key: true
      t.references :user,            null: false, foreign_key: true
      t.timestamps
    end
    add_index :encuesta_votos, [:encuesta_opcion_id, :user_id], unique: true, name: "idx_encuesta_voto_opcion_user"

    # ── 4. Feed / Muro ──
    create_table :publicaciones do |t|
      t.references :user,  null: false, foreign_key: true
      t.references :logia, null: false, foreign_key: true
      t.text       :contenido, null: false
      t.boolean    :fijada,    null: false, default: false
      t.integer    :likes_count,       null: false, default: 0
      t.integer    :comentarios_count, null: false, default: 0
      t.timestamps
    end
    add_index :publicaciones, [:logia_id, :created_at], order: { created_at: :desc }

    create_table :publicacion_comentarios do |t|
      t.references :publicacion, null: false, foreign_key: true
      t.references :user,        null: false, foreign_key: true
      t.text       :contenido,   null: false
      t.timestamps
    end

    create_table :publicacion_likes do |t|
      t.references :publicacion, null: false, foreign_key: true
      t.references :user,        null: false, foreign_key: true
      t.timestamps
    end
    add_index :publicacion_likes, [:publicacion_id, :user_id], unique: true, name: "idx_pub_like_pub_user"
  end
end
