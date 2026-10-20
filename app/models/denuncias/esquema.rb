module Denuncias
  # Los triggers que hacen de denuncias_eventos_custodia una tabla de solo inserción. schema.rb no
  # guarda triggers, así que se aseguran (idempotente) tras db:prepare, al cargar el esquema y en
  # las pruebas: una base creada desde cero no puede quedarse sin ellos.
  module Esquema
    SQL = <<~SQL.freeze
      CREATE OR REPLACE FUNCTION denuncias_custodia_solo_insercion() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'denuncias_eventos_custodia es solo de inserción';
      END;
      $$ LANGUAGE plpgsql;
      DROP TRIGGER IF EXISTS denuncias_custodia_sin_cambios ON denuncias_eventos_custodia;
      CREATE TRIGGER denuncias_custodia_sin_cambios
        BEFORE UPDATE OR DELETE ON denuncias_eventos_custodia
        FOR EACH ROW EXECUTE FUNCTION denuncias_custodia_solo_insercion();
      DROP TRIGGER IF EXISTS denuncias_custodia_sin_truncate ON denuncias_eventos_custodia;
      CREATE TRIGGER denuncias_custodia_sin_truncate
        BEFORE TRUNCATE ON denuncias_eventos_custodia
        FOR EACH STATEMENT EXECUTE FUNCTION denuncias_custodia_solo_insercion();
    SQL

    def self.triggers!(conexion = ActiveRecord::Base.connection)
      return unless conexion.table_exists?(:denuncias_eventos_custodia)
      conexion.execute(SQL)
    end
  end
end
