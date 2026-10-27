# El rol de administrador de una comunidad se llamaba «Admin Logia»; COMUNIA
# sirve a clubes, egresados y vecinos, así que se muestra con un nombre neutro.
# Solo cambia el nombre y la descripción si nadie los había editado.
class RenombrarRolAdminLogia < ActiveRecord::Migration[8.1]
  CODIGOS = "('admin_logia', 'admin')".freeze

  def up
    execute "UPDATE roles SET nombre = 'Administrador' WHERE codigo IN #{CODIGOS} AND nombre = 'Admin Logia'"
    execute "UPDATE roles SET descripcion = 'Administrador de una comunidad' WHERE codigo IN #{CODIGOS} AND descripcion = 'Administrador de una logia'"
  end

  def down
    execute "UPDATE roles SET nombre = 'Admin Logia' WHERE codigo IN #{CODIGOS} AND nombre = 'Administrador'"
    execute "UPDATE roles SET descripcion = 'Administrador de una logia' WHERE codigo IN #{CODIGOS} AND descripcion = 'Administrador de una comunidad'"
  end
end
