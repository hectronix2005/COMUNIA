# Los enlaces de ActiveStorage (/rails/active_storage/...) no caducan y Rails los sirve sin mirar la sesión: un
# soporte de pago o una plancha se podía abrir con el enlace guardado o reenviado, sin cuenta o desde otra
# comunidad. Aquí se exige que quien lo pide sea de la comunidad del registro al que pertenece el archivo. El logo
# de una comunidad es público (sale en su ingreso); la hoja de vida de la red, para cualquiera con sesión.
module ArchivosProtegidos
  extend ActiveSupport::Concern

  included do
    before_action :autorizar_archivo
  end

  private

  def autorizar_archivo
    blob = ActiveStorage::Blob.find_signed(params[:signed_blob_id] || params[:signed_id])
    registros = blob ? blob.attachments.includes(:record).filter_map(&:record) : []
    return if registros.any? { _1.is_a?(Logia) }

    user = request.env["warden"]&.user(:user)
    head :not_found unless user && registros.any? { |registro| ArchivosProtegidos.permitido?(user, registro) }
  end

  def self.permitido?(user, registro)
    return true if user.rol_ref&.es_super_admin?

    case registro
    when User then registro == user || comparten_comunidad?(user, registro)
    when Red::Perfil then true
    else
      logia = logia_de(registro)
      logia.present? && user.pertenece_a?(logia.organizacion)
    end
  end

  def self.logia_de(registro)
    case registro
    when Pago then registro.cobro&.miembro&.logia
    when MiembroEstadoCambio then registro.miembro&.logia
    else registro.try(:logia)
    end
  end

  def self.comparten_comunidad?(user, otro)
    user.pertenencias.where(organizacion_id: otro.pertenencias.select(:organizacion_id)).exists?
  end
end
