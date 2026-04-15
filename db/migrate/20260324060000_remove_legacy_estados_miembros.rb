class RemoveLegacyEstadosMiembros < ActiveRecord::Migration[8.0]
  def up
    # inactivo=1 y suspendido=2 → irregular_permanente=5
    execute <<~SQL
      UPDATE miembros
      SET estado = 5
      WHERE estado IN (1, 2)
    SQL

    # Actualizar también el historial de estado_cambios
    execute <<~SQL
      UPDATE miembro_estado_cambios
      SET estado = 'irregular_permanente',
          motivo = CASE
            WHEN estado = 'inactivo'   THEN COALESCE(motivo || ' ', '') || '[Migrado desde: Inactivo]'
            WHEN estado = 'suspendido' THEN COALESCE(motivo || ' ', '') || '[Migrado desde: Suspendido]'
            ELSE motivo
          END
      WHERE estado IN ('inactivo', 'suspendido')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
