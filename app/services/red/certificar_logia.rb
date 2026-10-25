module Red
  # Certifica una logia de COMUNIA como comunidad de la red (vínculo «logia», método «registro oficial»):
  # sus miembros activos quedan verificados por el propio registro de la logia, con la antigüedad de su
  # fecha de ingreso. Se puede repetir: sincroniza altas y bajas.
  module CertificarLogia
    module_function

    def call(logia, por:)
      c = Comunidad.find_or_initialize_by(logia_id: logia.id)
      Comunidad.transaction do
        if c.new_record?
          c.assign_attributes(nombre: nombre_libre(logia), tipo_vinculo: "logia", metodo_verificacion: "registro_oficial",
                              criterio: "Miembros activos de #{logia.nombre} según su registro en COMUNIA",
                              solicitada_por: por)
        end
        c.estado = "certificada"
        c.certificada_at ||= Time.current
        c.revisada_por = por
        c.save!
        sincronizar!(c, logia, por)
      end
      c
    end

    def sincronizar!(c, logia, por)
      activos = Miembro.activos.where(logia_id: logia.id).where.not(user_id: nil).pluck(:user_id, :fecha_ingreso).to_h
      activos.each do |user_id, ingreso|
        m = c.membresias.find_or_initialize_by(user_id: user_id)
        next if m.estado.in?(%w[revocada retirada]) && m.persisted?
        m.update!(estado: "verificada", verificada_por: por, rol: m.rol.presence || "miembro",
                  verificada_at: m.verificada_at || ingreso&.in_time_zone || Time.current,
                  vence_el: Membresia::VIGENCIA.from_now.to_date)
      end
      c.membresias.where(estado: "verificada").where.not(user_id: activos.keys).find_each do |m|
        m.update!(estado: "revocada", motivo: "Ya no es miembro activo de la logia")
      end
      c.recontar!
    end

    def nombre_libre(logia)
      base = logia.nombre.to_s[0, 70]
      Comunidad.exists?(["LOWER(nombre) = ?", base.downcase]) ? "#{base} (logia)" : base
    end
  end
end
