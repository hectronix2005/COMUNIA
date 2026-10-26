require "test_helper"

# Cada validación de unicidad tiene detrás un índice único: dos peticiones a la vez (un doble clic) pasan las dos
# la validación, y solo la base de datos impide el duplicado.
class IndicesUnicosTest < ActiveSupport::TestCase
  test "toda validación de unicidad tiene su índice único" do
    Rails.application.eager_load!
    faltan = ApplicationRecord.descendants.reject(&:abstract_class?).select(&:table_exists?).flat_map do |modelo|
      indices = modelo.connection.indexes(modelo.table_name).select(&:unique)
      modelo.validators.grep(ActiveRecord::Validations::UniquenessValidator).flat_map do |v|
        v.attributes.filter_map do |attr|
          columnas = [attr, *Array(v.options[:scope])].map { modelo.reflect_on_association(_1.to_sym)&.foreign_key&.to_s || _1.to_s }
          cubierto = indices.any? do |i|
            i.columns.is_a?(Array) ? i.columns.sort == columnas.sort : columnas.all? { i.columns.include?(_1) }
          end
          "#{modelo.table_name} #{columnas}" unless cubierto
        end
      end
    end
    assert_empty faltan
  end

  test "una persona no puede tener dos fichas de miembro aunque se salte la validación" do
    logia = Logia.create!(nombre: "Club Único", slug: "unico-#{SecureRandom.hex(3)}", codigo: "UN#{rand(10_000)}")
    user = User.create!(nombre: "Uma", apellido: "Prueba", email: "uma_#{SecureRandom.hex(3)}@correo.co", password: "password123", logia: logia)
    Miembro.create!(user: user, logia: logia, numero_miembro: "N1#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
    otra = Miembro.new(user: user, logia: logia, numero_miembro: "N2#{SecureRandom.hex(3)}", cedula: SecureRandom.hex(4), estado: :activo)
    assert_raises(ActiveRecord::RecordNotUnique) { otra.save(validate: false) }
  end
end
