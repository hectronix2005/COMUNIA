class CreateMiembroEstadoCambios < ActiveRecord::Migration[8.0]
  def up
    create_table :miembro_estado_cambios do |t|
      t.references :miembro, null: false, foreign_key: true
      t.string     :estado,  null: false
      t.date        :desde,   null: false
      t.date        :hasta
      t.string      :motivo
      t.references  :registrado_por, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :miembro_estado_cambios, [:miembro_id, :desde]

    # Backfill: un registro por miembro representando su estado actual
    execute <<~SQL
      INSERT INTO miembro_estado_cambios (miembro_id, estado, desde, hasta, motivo, created_at, updated_at)
      SELECT
        id,
        CASE estado
          WHEN 0 THEN 'activo'
          WHEN 1 THEN 'inactivo'
          WHEN 2 THEN 'suspendido'
          WHEN 3 THEN 'quite'
          WHEN 4 THEN 'irregular_temporal'
          WHEN 5 THEN 'irregular_permanente'
        END,
        COALESCE(estado_desde, created_at::date),
        estado_hasta,
        estado_motivo,
        NOW(),
        NOW()
      FROM miembros
    SQL
  end

  def down
    drop_table :miembro_estado_cambios
  end
end
