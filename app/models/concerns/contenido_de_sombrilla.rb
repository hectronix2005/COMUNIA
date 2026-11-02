# Lo que se publica en una sombrilla: lo firma una cuenta desde una de sus comunidades, se reporta y se oculta.
# Se oculta solo cuando lo reportan personas de REPORTES_PARA_OCULTAR comunidades distintas, o lo oculta un
# moderador (Sombrilla#modera?).
module ContenidoDeSombrilla
  extend ActiveSupport::Concern

  REPORTES_PARA_OCULTAR = 3

  included do
    belongs_to :user
    belongs_to :comunidad, class_name: "Logia"
    has_many :reportes, as: :reportable, class_name: "SombrillaReporte", dependent: :delete_all

    scope :visibles, -> { where(oculta: false) }
  end

  def reportado_por?(user) = reportes.exists?(user_id: user.id)

  # Devuelve true si con este reporte quedó oculto.
  def reportar!(user, comunidad)
    transaction do
      reportes.create_or_find_by!(user: user) { _1.comunidad = comunidad }
      if !oculta && reportes.distinct.count(:comunidad_id) >= REPORTES_PARA_OCULTAR
        update!(oculta: true)
        true
      else
        false
      end
    end
  end
end
