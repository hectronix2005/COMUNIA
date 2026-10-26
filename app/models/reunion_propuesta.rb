# Un punto que un convocado propone para el orden del día de una reunión, antes de que empiece. Solo lo ven quien
# lo propuso y quien gestiona la reunión, que lo incluye en el orden del día (con el nombre de quien lo propuso)
# o lo descarta.
class ReunionPropuesta < ApplicationRecord
  belongs_to :reunion
  belongs_to :miembro

  enum :estado, { pendiente: 0, incluida: 1, descartada: 2 }

  MAX_PENDIENTES = 3 # por persona y reunión

  validates :texto, presence: true, length: { maximum: 500 }
  validate :tope_de_pendientes, on: :create

  def incluir!
    linea = "- #{texto} (propone #{miembro.user.nombre_corto})"
    transaction do
      reunion.update!(orden_del_dia: [reunion.orden_del_dia.presence, linea].compact.join("\n"))
      incluida!
    end
  end

  private

  def tope_de_pendientes
    return unless reunion && miembro
    return if reunion.reunion_propuestas.pendiente.where(miembro: miembro).count < MAX_PENDIENTES
    errors.add(:base, "Ya tienes #{MAX_PENDIENTES} puntos esperando respuesta en esta convocatoria.")
  end
end
