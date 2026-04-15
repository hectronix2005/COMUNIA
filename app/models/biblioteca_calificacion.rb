class BibliotecaCalificacion < ApplicationRecord
  self.table_name = "biblioteca_calificaciones"

  belongs_to :libro, class_name: "BibliotecaLibro"
  belongs_to :user

  validates :puntuacion, presence: true,
                         numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :libro_id, uniqueness: { scope: :user_id, message: "ya calificaste este libro" }
end
