# El botón «Cambiar rol» de la ficha cambiaba rol_ref y dejaba el enum rol como estaba. Copia a rol el de
# rol_ref, que es el que da los permisos; desde ahora lo hace el modelo al guardar.
class IgualarRolDeUsersConRolRef < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE users
      SET rol = CASE roles.codigo WHEN 'super_admin' THEN 2 WHEN 'admin_logia' THEN 1 ELSE 0 END
      FROM roles
      WHERE roles.id = users.rol_ref_id
    SQL
  end

  # El valor anterior no se guarda: no hay vuelta atrás, ni hace falta (el enum no da permisos).
  def down; end
end
