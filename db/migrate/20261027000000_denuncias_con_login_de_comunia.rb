# DENUNCIAPP pasa al login de COMUNIA (decisión de Héctor, 26-oct-2026): la denuncia queda ligada al
# usuario que la publica. Salen las cuentas con alias, los pases anónimos y el código de seguimiento.
# En producción las tres tablas y denuncias_reportes estaban vacías (comprobado antes de migrar).
class DenunciasConLoginDeComunia < ActiveRecord::Migration[8.1]
  def up
    remove_column :denuncias_reportes, :cuenta_id
    remove_column :denuncias_reportes, :codigo_hash
    remove_column :denuncias_reportes, :sello_publico
    add_reference :denuncias_reportes, :user, foreign_key: { on_delete: :nullify }

    drop_table :denuncias_cuentas
    drop_table :denuncias_pases_usados
    drop_table :pases_semanales
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
