module MiembrosHelper
  ACCESO = {
    entro:               ["bg-success", "Ha entrado"],
    invitado:            ["bg-info text-dark", "Invitado"],
    invitacion_caducada: ["bg-warning text-dark", "Invitación caducada"],
    nunca:               ["bg-secondary", "Nunca ha entrado"]
  }.freeze

  def acceso_badge(user)
    clase, texto = ACCESO.fetch(user.acceso)
    tag.span(texto, class: "badge #{clase}")
  end

  # Enlace de WhatsApp con el mensaje escrito. Con un celular colombiano o un número con indicativo va
  # directo a ese chat; sin número, WhatsApp deja elegir el contacto.
  def whatsapp_url(telefono, texto)
    digitos = telefono.to_s.gsub(/\D/, "")
    digitos = "57#{digitos}" if digitos.length == 10 && digitos.start_with?("3")
    destino = digitos.length >= 11 ? digitos : ""
    "https://wa.me/#{destino}?text=#{ERB::Util.url_encode(texto)}"
  end
end
