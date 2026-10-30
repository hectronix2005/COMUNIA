# Recorrido guiado, pantalla a pantalla (recorrido_controller.js). Cada paso dice a qué pantalla ir, qué elemento
# resaltar (el que lleva data-recorrido="<foco>" en la vista; si no está, el globo sale centrado) y qué contar.
# Los pasos «opcionales» se saltan cuando su elemento no está (no hay próxima reunión, los avisos ya están activos).
module RecorridoHelper
  def recorrido_disponible?
    user_signed_in? && !current_user.debe_completar_datos? && !platform_admin_context? && current_logia.present?
  end

  # Arranca solo la primera vez. El invitado de la demostración comparte cuenta: lo recuerda el navegador.
  def recorrido_automatico?
    current_user.invitado? || current_user.recorrido_visto_at.nil?
  end

  def pasos_del_recorrido
    logia = current_logia
    pasos = [
      paso(dashboard_path, "saludo", "Te damos la bienvenida",
           "En un minuto te enseño dónde está cada cosa en #{logia.nombre_display}. Puedes salir cuando quieras; " \
           "el recorrido queda en la Guía para repetirlo."),
      paso(dashboard_path, "avisos", "Activa los avisos",
           "Así te llegan al teléfono las convocatorias y los recordatorios, sin tener que entrar a mirar.",
           opcional: true),
      paso(dashboard_path, "proxima", "Lo próximo",
           "Aquí aparece el siguiente encuentro. Confirma si vas con un toque: quien organiza lo ve al instante.",
           opcional: true),
      *paso_de_mis_cuotas(logia),
      paso(calendario_index_path, "agenda", "La agenda",
           "Todos los encuentros y eventos del mes. Toca un día para ver qué hay; también puedes llevarla al " \
           "calendario de tu teléfono."),
      paso(publicaciones_path, "muro", "El muro",
           "Las noticias de la comunidad. Publica, comenta y reacciona: lo ven los miembros de tu comunidad."),
      paso(chat_path, "chat", "El chat",
           "Conversa con toda la comunidad en el canal general o escribe a una persona en privado."),
      paso(directorio_index_path, "directorio", "El directorio",
           "Encuentra a los demás y cómo contactarlos. En «Mi perfil» completas tu propia ficha.")
    ]
    if logia.modulo?(:tesoreria) && current_user.tiene_cargo?("Tesorero")
      pasos << paso(cobros_path, "cobros", "Los cobros",
                    "Para tesorería: genera los cobros, valida los soportes de pago y sigue la cartera.")
    end
    if current_user.tiene_permiso?("miembros", "index")
      pasos << paso(miembros_path, "miembros", "Quienes forman la comunidad",
                    "Para quien administra: aquí das de alta a los miembros y los invitas a entrar.")
    end
    pasos << paso(guia_path, "guia", "Todo, en la Guía",
                  "Lo que puedes hacer en cada sección, con un enlace para ir. Desde aquí repites este recorrido.")
  end

  private

  # Los cobros del miembro están en su inicio («Mis cobros»); la pantalla de cobros es solo para tesorería.
  def paso_de_mis_cuotas(logia)
    return [] unless logia.modulo?(:tesoreria) && current_user.miembro.present? && !current_user.tiene_cargo?("Tesorero")
    [ paso(dashboard_path, "cobros", "Tus cuotas",
           "Lo que tienes pendiente y lo ya pagado. Marca los cobros y envía el soporte de tu pago desde aquí.",
           opcional: true) ]
  end

  def paso(ruta, foco, titulo, texto, opcional: false)
    { ruta:, foco:, titulo:, texto:, opcional: }
  end
end
