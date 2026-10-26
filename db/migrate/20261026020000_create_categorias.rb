# Categorías de comunidad (Masonería, Club, Barrio, Universidad…): el superadmin define en cada una cómo se
# llaman las cosas y qué módulos se ven. Cada comunidad raíz pertenece a una; sus grupos la heredan.
class CreateCategorias < ActiveRecord::Migration[8.1]
  TODOS = %w[tesoreria documentos biblioteca ayuda negocios grados].freeze

  PREDETERMINADAS = [
    ["Masonería",   "bank",          "Hermano",  "Logia",    "Cuota",  "Tenida",    "Hospitalía",      "Planchas",   TODOS],
    ["Club",        "car-front",     "Socio",    "Grupo",    "Cuota",  "Encuentro", "Fondo social",    "Documentos", TODOS - %w[grados]],
    ["Barrio",      "houses",        "Vecino",   "Conjunto", "Cuota",  "Asamblea",  "Fondo común",     "Actas",      TODOS - %w[grados biblioteca]],
    ["Universidad", "mortarboard",   "Egresado", "Cohorte",  "Aporte", "Encuentro", "Fondo solidario", "Documentos", TODOS - %w[grados]]
  ].freeze

  def up
    create_table :categorias do |t|
      t.string :nombre, null: false
      t.string :icono
      t.string :termino_miembro
      t.string :termino_logia
      t.string :termino_cobro
      t.string :termino_reunion
      t.string :termino_ayuda
      t.string :termino_documentos
      t.string :modulos, array: true, null: false, default: []
      t.timestamps
    end
    add_index :categorias, "lower(nombre)", unique: true, name: "index_categorias_on_lower_nombre"
    add_reference :logias, :categoria, foreign_key: true

    PREDETERMINADAS.each do |nombre, icono, miembro, logia, cobro, reunion, ayuda, documentos, modulos|
      execute sanitize_sql([<<~SQL, nombre, icono, miembro, logia, cobro, reunion, ayuda, documentos, "{#{modulos.join(',')}}"])
        INSERT INTO categorias (nombre, icono, termino_miembro, termino_logia, termino_cobro, termino_reunion,
                                termino_ayuda, termino_documentos, modulos, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, now(), now())
      SQL
    end

    # Las comunidades raíz que ya existen: las que se llaman «club» van a Club; las demás, a Masonería, que
    # tiene todos los módulos (nadie pierde nada). «Logias» como término de subgrupo era un plural puesto a
    # mano: se vacía para que salga el de la categoría («Logia»).
    execute <<~SQL
      UPDATE logias SET categoria_id = (SELECT id FROM categorias WHERE nombre = CASE
        WHEN logias.nombre ILIKE 'club%' THEN 'Club' ELSE 'Masonería' END)
      WHERE tenant_id IS NULL
    SQL
    execute "UPDATE logias SET termino_logia = NULL WHERE termino_logia = 'Logias'"
  end

  def down
    remove_reference :logias, :categoria, foreign_key: true
    drop_table :categorias
  end

  private

  def sanitize_sql(args) = ActiveRecord::Base.sanitize_sql_array(args)
end
