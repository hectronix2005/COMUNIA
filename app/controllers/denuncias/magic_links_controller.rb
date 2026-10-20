module Denuncias
  # Consume el enlace mágico (devise-passwordless). Devise lo hace heredar de ApplicationController
  # (parent_controller es global): en el host de DENUNCIAPP no hay sesión de COMUNIA, así que sus
  # filtros no hacen nada, y aquí se fija adónde volver y qué pasa si el enlace no vale.
  class MagicLinksController < Devise::MagicLinksController
    skip_after_action :track_last_seen, raise: false
    before_action { head :not_found unless Denuncias.host?(request) && Denuncias.cuentas? }

    protected

    def auth_options = { scope: resource_name } # sin «recall» a las vistas de Devise de COMUNIA
    def after_sign_in_path_for(_resource) = "/cuenta"
  end
end
