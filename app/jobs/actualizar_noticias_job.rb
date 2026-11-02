# Trae las noticias de las comunidades con Noticias encendido y de las sombrillas con alguna comunidad anclada
# debajo (cada mañana, y al guardar las búsquedas de una comunidad). Guarda las nuevas, no toca las ocultas y
# borra las de más de Noticia::DIAS días o las que sobran.
class ActualizarNoticiasJob < ApplicationJob
  queue_as :default

  def perform(logia_id = nil)
    comunidades = Logia.tenants_raiz.where(noticias_activas: true)
    comunidades = comunidades.where(id: logia_id) if logia_id
    comunidades.find_each { actualizar(_1) }
    sombrillas_con_gente.each { actualizar(_1) } unless logia_id
  end

  private

  def sombrillas_con_gente
    barrios = Sombrilla.where(id: Logia.where.not(sombrilla_id: nil).select(:sombrilla_id))
    barrios.flat_map(&:cadena).uniq
  end

  def actualizar(duenio)
    duenio.noticias_busquedas.each do |frase|
      Noticias::GoogleNoticias.buscar(frase).each do |datos|
        duenio.noticias.create_or_find_by!(url: datos[:url]) { _1.assign_attributes(datos.merge(busqueda: frase)) }
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("noticias: #{duenio.class.name} #{duenio.id}: #{e.message}")
      end
    rescue StandardError => e
      Rails.logger.warn("noticias: #{duenio.class.name} #{duenio.id} «#{frase}»: #{e.class}: #{e.message}")
    end
    duenio.noticias.where(publicada_en: ...Noticia::DIAS.days.ago).delete_all
    sobran = duenio.noticias.recientes.offset(Noticia::MAXIMO).pluck(:id)
    duenio.noticias.where(id: sobran).delete_all if sobran.any?
  end
end
