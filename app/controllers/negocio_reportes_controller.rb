class NegocioReportesController < ApplicationController
  def create
    anuncio = NegocioAnuncio.find_by_slug_or_id(params[:negocio_id])
    reporte = anuncio.reportes.new(
      user:        current_user,
      motivo:      params.dig(:negocio_reporte, :motivo),
      descripcion: params.dig(:negocio_reporte, :descripcion)
    )

    if reporte.save
      redirect_to negocio_path(anuncio), notice: "Gracias, tu reporte fue enviado a los administradores."
    else
      redirect_to negocio_path(anuncio), alert: reporte.errors.full_messages.to_sentence
    end
  end
end
