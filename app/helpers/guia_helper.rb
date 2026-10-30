# Guía (GuiaController): lo que cada uno puede hacer, por secciones. Muestra solo lo que su comunidad tiene activo y lo
# que su rol permite, con las mismas condiciones del menú (layouts/application).
module GuiaHelper
  def secciones_de_la_guia
    logia = current_logia
    secciones = []

    dia = [
      guia_item("bi-house", "Inicio", "Tu resumen: el próximo encuentro, lo que tienes pendiente y lo último de la comunidad.", dashboard_path),
      guia_item("bi-calendar3", "Agenda", "Los encuentros y eventos del mes. Llévala al calendario de tu teléfono.", calendario_index_path)
    ]
    if logia.modulo?(:reuniones)
      dia << guia_item("bi-people", logia.t_reuniones, "Convocatorias, asistencia y actas. Confirma si vas con un toque.", reuniones_path)
    end
    dia << guia_item("bi-balloon-heart", "Cumpleaños", "Quién cumple este mes, para que nadie quede sin saludo.", hospitalia_cumpleanos_path)
    dia << guia_item("bi-bell", "Notificaciones", "Todo lo que te ha llegado: convocatorias, respuestas y recordatorios.", notificaciones_path)
    secciones << ["Tu día a día", dia]

    secciones << ["Conversar", [
      guia_item("bi-newspaper", "Muro", "Las noticias de la comunidad. Publica, comenta y reacciona.", publicaciones_path),
      guia_item("bi-chat-dots", "Chat", "El canal general de la comunidad y las conversaciones en privado.", chat_path),
      guia_item("bi-bar-chart", "Encuestas", "Vota en lo que la comunidad decide y mira los resultados.", encuestas_path),
      guia_item("bi-person-vcard", "Directorio", "Encuentra a los demás y cómo contactarlos.", directorio_index_path)
    ]]

    if logia.modulo?(:tesoreria) && current_user.tiene_cargo?("Tesorero")
      secciones << ["Cuotas", [ guia_item("bi-receipt", Logia.plural(logia.t_cobro),
                                          "Genera los cobros, valida los soportes de pago y sigue la cartera.", cobros_path) ]]
    elsif logia.modulo?(:tesoreria) && current_user.miembro.present?
      secciones << ["Cuotas", [ guia_item("bi-receipt", "Mis #{Logia.plural(logia.t_cobro)}",
                                          "Lo pendiente y lo ya pagado, en tu inicio. Desde ahí envías el soporte de tu pago.",
                                          dashboard_path(anchor: "mis-cobros")) ]]
    end

    biblioteca = []
    if logia.modulo?(:documentos)
      biblioteca << guia_item("bi-file-earmark-text", logia.t_documentos, "Los trabajos y documentos que comparte la comunidad.", biblioteca_planchas_path)
    end
    if logia.modulo?(:biblioteca)
      biblioteca << guia_item("bi-book", "Libros", "Lecturas recomendadas y la opinión de los demás.", biblioteca_libros_path)
    end
    if logia.modulo?(:negocios)
      biblioteca << guia_item("bi-briefcase", "Negocios", "Lo que ofrecen los miembros: contrata y recomienda entre la comunidad.", negocios_path)
    end
    secciones << ["Biblioteca y más", biblioteca] if biblioteca.any?

    cuenta = []
    if current_user.miembro.present?
      cuenta << guia_item("bi-person-badge", "Tu ficha", "Tus datos en el directorio: foto, teléfono y lo que quieras contar.",
                          edit_directorio_path(current_user.miembro))
    end
    cuenta << guia_item("bi-person-circle", "Tu nombre en el chat", "Cómo te ven los demás al conversar.", perfil_path)
    cuenta << guia_item("bi-phone", "Instala la app", "Añádela a la pantalla de inicio y activa los avisos.", bienvenida_path)
    secciones << ["Tu cuenta", cuenta]

    admin = []
    if current_user.tiene_permiso?("miembros", "index")
      admin << guia_item("bi-person-plus", Logia.plural(logia.t_miembro).capitalize,
                         "Da de alta a las personas de la comunidad y envíales su acceso.", miembros_path)
    end
    if current_user.tiene_permiso?("logias", "index")
      admin << guia_item("bi-sliders", "Tu comunidad", "Nombre, logo, color y los módulos que tiene activos.", logia_path(logia))
    end
    if current_user.tiene_permiso?("roles", "index")
      admin << guia_item("bi-shield-lock", "Roles", "Quién puede hacer qué dentro de la comunidad.", roles_path)
    end
    secciones << ["Para quien administra", admin] if admin.any?

    secciones
  end

  private

  def guia_item(icono, titulo, texto, ruta)
    { icono:, titulo:, texto:, ruta: }
  end
end
