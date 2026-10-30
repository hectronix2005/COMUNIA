class IngresoPorCelular < ActiveRecord::Migration[8.1]
  # Ingreso con el celular (decisión de Héctor, 29-oct-2026): hay personas de las que la comunidad solo tiene el
  # nombre y el celular. Entran con él y una contraseña temporal, y al primer ingreso eligen la suya y completan
  # correo, apellidos, cédula y lo que pida su comunidad (debe_completar_datos). Mientras tanto no tienen correo
  # (NULL: no choca con el índice único) ni cédula.
  def up
    add_column :users, :celular, :string
    add_index :users, :celular, unique: true
    add_column :users, :debe_completar_datos, :boolean, default: false, null: false
    change_column_default :users, :email, from: "", to: nil
    change_column_null :users, :email, true
    change_column_null :miembros, :cedula, true
  end

  def down
    change_column_null :miembros, :cedula, false
    change_column_null :users, :email, false, ""
    change_column_default :users, :email, from: nil, to: ""
    remove_column :users, :debe_completar_datos
    remove_index :users, :celular
    remove_column :users, :celular
  end
end
