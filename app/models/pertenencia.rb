# Que una cuenta es de una comunidad (organización raíz), con su logia y su rol allí. Una cuenta puede ser de
# varias; la activa es la que guardan users.logia_id y users.rol_ref_id, que es lo que lee el resto de la app
# (User#activar_comunidad!). La de la comunidad activa la mantiene User al guardarse.
class Pertenencia < ApplicationRecord
  belongs_to :user
  belongs_to :organizacion, class_name: "Logia"
  belongs_to :logia
  belongs_to :rol_ref, class_name: "Rol", optional: true

  validates :organizacion_id, uniqueness: { scope: :user_id }
  validate { errors.add(:logia, "no es de esa comunidad") if logia && logia.organizacion.id != organizacion_id }

  before_validation { self.organizacion = logia.organizacion if logia }
end
