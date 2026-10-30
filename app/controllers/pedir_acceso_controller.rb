# Página pública para pedir entrar a una comunidad con el código que dio un administrador y una prueba de
# pertenencia. La cuenta es de Devise y nace en espera: no entra hasta que un administrador de esa logia la
# apruebe (SolicitudesAccesoController). Captcha, consentimiento y límite de intentos (rack_attack.rb).
class PedirAccesoController < ApplicationController
  include FormularioPublico

  skip_before_action :authenticate_user!
  before_action { redirect_to(current_user.invitado? ? demo_participar_path : root_path) if user_signed_in? }

  def new
    @datos = {}
  end

  def create
    @datos = { codigo: texto(:codigo, 20), nombre: texto(:nombre, 60), apellido: texto(:apellido, 60),
               email: texto(:email, 120)&.downcase, prueba: texto(:prueba, 1000) }
    return volver("Acepta la política de datos para pedir acceso.") unless params[:acepto] == "1"
    return volver("Hoy no podemos recibir solicitudes. Inténtalo más tarde.") unless captcha_disponible?
    return volver("Confirma que no eres un robot.") unless captcha_valido?

    logia = Logia.por_codigo_acceso(@datos[:codigo])
    return volver("Ese código no corresponde a ninguna comunidad. Pídeselo otra vez a un administrador.") unless logia
    if logia.solicitudes_acceso.pendiente.count >= SolicitudAcceso::MAX_PENDIENTES
      return volver("Esta comunidad tiene muchas solicitudes por revisar. Inténtalo en unos días.")
    end
    if User.exists?(email: @datos[:email])
      return volver("Ese correo ya tiene cuenta: entra con él, o pide a un administrador un enlace para entrar.")
    end

    user = User.new(nombre: @datos[:nombre], apellido: @datos[:apellido], email: @datos[:email],
                    password: texto(:password, 128), password_confirmation: texto(:password_confirmation, 128),
                    solo_red: true, espera_aprobacion: true, rol: :miembro)
    solicitud = logia.solicitudes_acceso.new(@datos.except(:codigo).merge(user: user))
    return volver([user, solicitud].flat_map { _1.errors.full_messages }.to_sentence) unless user.valid? & solicitud.valid?

    SolicitudAcceso.transaction { user.save! && solicitud.save! }
    avisar_administradores(solicitud)
    flash[:comunidad] = logia.nombre_display
    redirect_to pedir_acceso_enviada_path
  end

  def enviada
    # Se saca del flash para que el layout no lo pinte también como aviso.
    @comunidad = flash[:comunidad]
    flash.delete(:comunidad)
  end

  private

  def volver(mensaje)
    flash.now[:alert] = mensaje
    render :new, status: :unprocessable_content
  end

  # A quienes pueden resolverla: los que editan fichas en esa logia o en su organización.
  def avisar_administradores(solicitud)
    logia = solicitud.logia
    # Por pertenencia y con el rol de esa comunidad: un admin de aquí puede tener activa otra.
    Pertenencia.where(logia_id: [logia.id, logia.tenant_id].compact).includes(:user, :rol_ref).find_each do |pertenencia|
      rol = pertenencia.rol_ref
      next unless rol && (rol.es_super_admin? || rol.tiene_permiso?("miembros", "update"))
      NotificacionService.crear!(user: pertenencia.user, tipo: "solicitud_acceso", logia: logia, url: "/solicitudes/#{solicitud.id}",
                                 titulo: "#{solicitud.nombre_completo} pide entrar a #{logia.nombre_display}",
                                 cuerpo: "Revisa su prueba y apruébala o recházala.")
    end
  end
end
