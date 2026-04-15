class CreateCorteConciliaciones < ActiveRecord::Migration[8.0]
  def change
    create_table :corte_conciliaciones do |t|
      t.date     :fecha_corte,    null: false
      t.string   :descripcion
      t.integer  :estado,         null: false, default: 0
      t.jsonb    :resultado,      null: false, default: {}
      t.string   :formato_archivo
      t.integer  :total_archivo,  default: 0
      t.integer  :total_sistema,  default: 0
      t.references :logia,        null: false, foreign_key: true
      t.references :creado_por,   null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :corte_conciliaciones, [:logia_id, :fecha_corte], unique: true
  end
end
