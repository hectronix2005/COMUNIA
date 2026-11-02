module SombrillasHelper
  # «Angela B. · Edificio Alborada 140», o «Vecino de Edificio Alborada 140» si no muestra su nombre. Quien
  # modera ve además el nombre completo de quien no lo muestra (el suyo no: ya sabe quién es).
  def autor_en_sombrilla(registro, modera:)
    user = registro.user
    comunidad = registro.comunidad
    nombre = user.nombre_en_sombrilla
    publico = nombre ? "#{nombre} · #{comunidad.nombre_display}" : "#{comunidad.t_miembro} de #{comunidad.nombre_display}"
    return publico unless modera && user != current_user && nombre != user.nombre_completo.squish

    safe_join([publico, " ", tag.span("(#{user.nombre_completo.squish})", class: "text-muted fw-normal", title: "Solo lo ven los moderadores")])
  end

  # Cómo se vería la cuenta con cada opción, para elegir.
  def ejemplo_visibilidad(user, valor, comunidad)
    nombre = user.nombre_en_sombrilla(valor)
    return "«#{comunidad.t_miembro} de #{comunidad.nombre_display}»" unless nombre

    "«#{nombre} · #{comunidad.nombre_display}»"
  end
end
