# Las validaciones de unicidad sin índice único dejan pasar duplicados cuando llegan dos peticiones a la vez
# (doble clic, reintento del navegador). El índice es la garantía; la validación, el mensaje bonito.
# En producción no había duplicados al crearlos (comprobado el 26-oct-2026).
class AddIndicesUnicosFaltantes < ActiveRecord::Migration[8.1]
  def change
    remove_index :miembros, :user_id, name: "index_miembros_on_user_id"
    add_index :miembros, :user_id, unique: true
    add_index :negocio_reportes, [:negocio_anuncio_id, :user_id], unique: true
    add_index :conceptos_cobros, [:logia_id, :nombre], unique: true
    add_index :red_comunidades, "lower(nombre)", unique: true, name: "index_red_comunidades_on_lower_nombre"
  end
end
