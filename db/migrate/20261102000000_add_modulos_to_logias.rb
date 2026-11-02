# Los módulos de una comunidad: nil usa los de su categoría; una lista (aunque esté vacía) manda sobre ella.
class AddModulosToLogias < ActiveRecord::Migration[8.1]
  def change
    add_column :logias, :modulos, :string, array: true
  end
end
