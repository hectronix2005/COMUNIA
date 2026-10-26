# Cada periodo de cobro es de una organización (logia raíz): antes era único por año y mes en toda la plataforma
# y generar_cobros! cobraba a los miembros de todas las organizaciones.
class AddTenantToPeriodoCobros < ActiveRecord::Migration[8.1]
  def up
    add_reference :periodo_cobros, :tenant, foreign_key: { to_table: :logias }

    # La organización de un periodo es la de sus cobros; sin cobros, la del creador; si no, la primera raíz.
    execute <<~SQL
      UPDATE periodo_cobros p SET tenant_id = COALESCE(
        (SELECT COALESCE(l.tenant_id, l.id) FROM cobros c JOIN miembros m ON m.id = c.miembro_id
           JOIN logias l ON l.id = m.logia_id WHERE c.periodo_cobro_id = p.id
           GROUP BY 1 ORDER BY count(*) DESC, 1 LIMIT 1),
        (SELECT COALESCE(l.tenant_id, l.id) FROM users u JOIN logias l ON l.id = u.logia_id WHERE u.id = p.creado_por_id),
        (SELECT id FROM logias WHERE tenant_id IS NULL ORDER BY id LIMIT 1))
    SQL

    change_column_null :periodo_cobros, :tenant_id, false
    remove_index :periodo_cobros, [:anio, :mes]
    add_index :periodo_cobros, [:tenant_id, :anio, :mes], unique: true
    remove_index :periodo_cobros, :tenant_id
  end

  def down
    add_index :periodo_cobros, :tenant_id
    remove_index :periodo_cobros, [:tenant_id, :anio, :mes]
    add_index :periodo_cobros, [:anio, :mes], unique: true
    remove_reference :periodo_cobros, :tenant, foreign_key: { to_table: :logias }
  end
end
