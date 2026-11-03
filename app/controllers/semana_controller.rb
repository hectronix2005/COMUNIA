# Lo de esta semana en la comunidad (ResumenSemanal), adonde lleva el aviso de los lunes. Quien administra la
# comunidad tiene además el texto listo para el grupo de WhatsApp.
class SemanaController < ApplicationController
  def show
    @resumen = ResumenSemanal.new(current_logia, user: current_user)
    @whatsapp = ResumenSemanal.new(current_logia).texto_whatsapp(semana_url) if admin_de_la_comunidad?
  end
end
