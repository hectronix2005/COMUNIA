# Trae las noticias de las comunidades con Noticias encendido (cada mañana, y al guardar las búsquedas).
# Guarda las nuevas, no toca las ocultas y borra las de más de Noticia::DIAS días o las que sobran.
class ActualizarNoticiasJob < ApplicationJob
  queue_as :default

  def perform(logia_id = nil)
    comunidades = Logia.tenants_raiz.where(noticias_activas: true)
    comunidades = comunidades.where(id: logia_id) if logia_id
    comunidades.find_each { actualizar(_1) }
  end

  private

  def actualizar(comunidad)
    comunidad.noticias_busquedas.each do |frase|
      Noticias::GoogleNoticias.buscar(frase).each do |datos|
        comunidad.noticias.create_or_find_by!(url: datos[:url]) { _1.assign_attributes(datos.merge(busqueda: frase)) }
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("noticias: #{comunidad.id}: #{e.message}")
      end
    rescue StandardError => e
      Rails.logger.warn("noticias: #{comunidad.id} «#{frase}»: #{e.class}: #{e.message}")
    end
    comunidad.noticias.where(publicada_en: ...Noticia::DIAS.days.ago).delete_all
    sobran = comunidad.noticias.recientes.offset(Noticia::MAXIMO).pluck(:id)
    comunidad.noticias.where(id: sobran).delete_all if sobran.any?
  end
end
