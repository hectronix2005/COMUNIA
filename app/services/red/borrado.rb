module Red
  # Ley 1581, supresión: borra todo lo de una persona en la red. Las conversaciones en las que participó
  # se borran enteras (con los mensajes de la otra parte, que sin ella no tienen sentido). Lo que otras
  # personas hicieron con su firma (avalar membresías, resolver reportes) queda sin autor.
  # Si la cuenta es solo de la red, se borra la cuenta.
  module Borrado
    module_function

    def call(user)
      ActiveRecord::Base.transaction do
        conversaciones = Conversacion.where(iniciador_id: user.id).or(Conversacion.where(destinatario_id: user.id))
        Resena.where(conversacion_id: conversaciones.select(:id)).delete_all
        Resena.where(autor_id: user.id).or(Resena.where(sujeto_id: user.id)).delete_all
        Mensaje.where(conversacion_id: conversaciones.select(:id)).delete_all
        Reporte.where(objeto_type: "Red::Mensaje", objeto_id: Mensaje.where(user_id: user.id).select(:id)).delete_all
        Mensaje.where(user_id: user.id).delete_all
        conversaciones.delete_all
        Bloqueo.where(user_id: user.id).or(Bloqueo.where(bloqueado_id: user.id)).delete_all
        Reporte.where(reportante_id: user.id).update_all(reportante_id: nil)
        Reporte.where(resuelto_por_id: user.id).update_all(resuelto_por_id: nil)
        Membresia.where(verificada_por_id: user.id).update_all(verificada_por_id: nil)
        Comunidad.where(solicitada_por_id: user.id).update_all(solicitada_por_id: nil)
        Comunidad.where(revisada_por_id: user.id).update_all(revisada_por_id: nil)
        Reporte.where(objeto_type: "Red::Publicacion", objeto_id: user.red_publicaciones.select(:id)).delete_all
        Conversacion.where(publicacion_id: user.red_publicaciones.select(:id)).update_all(publicacion_id: nil)
        user.red_publicaciones.find_each(&:destroy!)
        comunidades = user.red_membresias.pluck(:comunidad_id)
        user.red_membresias.delete_all
        Comunidad.where(id: comunidades).find_each(&:recontar!)
        if (perfil = user.red_perfil)
          Reporte.where(objeto: perfil).delete_all
          perfil.hoja_de_vida.purge if perfil.hoja_de_vida.attached?
          perfil.destroy!
        end
        Confianza.where(user_id: user.id).delete_all
        user.notificaciones.where("tipo LIKE 'red_%'").delete_all
        user.destroy! if user.solo_red?
      end
    end
  end
end
