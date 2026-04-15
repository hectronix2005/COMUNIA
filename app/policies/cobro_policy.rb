class CobroPolicy < ApplicationPolicy
  def index?
    tiene_permiso?("cobros", "index") || user.miembro.present?
  end

  def show?
    tiene_permiso?("cobros", "show") || es_mi_cobro?
  end

  def adjuntar_soporte?
    es_mi_cobro? && record.puede_adjuntar_soporte?
  end

  def subir_soporte?
    adjuntar_soporte?
  end

  def parsear_soporte?
    user.miembro.present? || tiene_permiso?("cobros", "validar")
  end

  def adjuntar_soporte_multiple?
    user.miembro.present? || tiene_permiso?("cobros", "validar")
  end

  def subir_soporte_multiple?
    user.miembro.present? || tiene_permiso?("cobros", "validar")
  end

  def validar?
    tiene_permiso?("cobros", "validar") && record.puede_validar?
  end

  def confirmar_pago?
    tiene_permiso?("cobros", "confirmar_pago") && record.puede_validar?
  end

  def rechazar_pago?
    tiene_permiso?("cobros", "rechazar_pago") && record.soporte_adjunto?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.tiene_permiso?("cobros", "index")
        if user.scope_propia_logia?
          scope.por_logia(user.logia_id)
        else
          scope.all
        end
      else
        scope.where(miembro_id: user.miembro&.id)
      end
    end
  end

  private

  def es_mi_cobro?
    user.miembro.present? && record.miembro_id == user.miembro&.id
  end
end
