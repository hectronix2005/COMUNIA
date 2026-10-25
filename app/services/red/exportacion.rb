module Red
  # Ley 1581, derecho de acceso: todo lo que la red guarda de una persona. Lo que es de otras personas
  # (sus mensajes, quién reportó, qué verificador aprobó) no sale; sí sale lo que la persona escribió.
  module Exportacion
    module_function

    def de(user)
      perfil = user.red_perfil
      {
        generado_el: Time.current.iso8601,
        politica_version: perfil&.politica_version,
        cuenta: { nombre: user.nombre, apellido: user.apellido, email: user.email, creada_el: user.created_at.iso8601 },
        perfil: perfil && perfil.slice(:nombre_publico, :titular, :bio, :ciudad, :habilidades, :alcance, :visible_publico,
                                       :contacto_telefono, :contacto_correo, :acepto_tratamiento_at, :cuarentena_hasta,
                                       :sanciones, :suspendido_at, :created_at)
                                .merge(hoja_de_vida: perfil.hoja_de_vida.attached? ? perfil.hoja_de_vida.filename.to_s : nil),
        confianza: Confianza.de(user).slice(:nivel, :comunidades, :banda_miembros, :calculada_at),
        comunidades: user.red_membresias.includes(:comunidad).map do |m|
          { comunidad: m.comunidad.nombre, estado: m.estado, rol: m.rol, evidencia: m.evidencia,
            verificada_el: m.verificada_at&.iso8601, vence_el: m.vence_el&.iso8601, motivo: m.motivo }
        end,
        publicaciones: user.red_publicaciones.map do |p|
          p.slice(:intencion, :categoria, :titulo, :descripcion, :ciudad, :modalidad, :precio_texto, :estado, :alcance,
                  :vence_el, :created_at)
        end,
        mensajes_escritos: Mensaje.where(user_id: user.id).order(:created_at).map { { cuerpo: _1.cuerpo, enviado_el: _1.created_at.iso8601 } },
        resenas_escritas: Resena.where(autor_id: user.id).map { _1.slice(:puntaje, :comentario, :created_at) },
        resenas_recibidas: Resena.where(sujeto_id: user.id).map { _1.slice(:puntaje, :comentario, :respuesta, :created_at) },
        bloqueos: Bloqueo.where(user_id: user.id).count,
        reportes_hechos: Reporte.where(reportante_id: user.id).map { _1.slice(:motivo, :detalle, :estado, :created_at) }
      }
    end
  end
end
