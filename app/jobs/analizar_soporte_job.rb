class AnalizarSoporteJob < ApplicationJob
  queue_as :default

  def perform(pago_id)
    pago = Pago.find_by(id: pago_id)
    return unless pago&.soportes&.attached?
    return if pago.datos_ocr.present?

    # Analizar el primer soporte (principal)
    primer_soporte = pago.soportes.first
    primer_soporte.open do |tempfile|
      archivo = ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: primer_soporte.filename.to_s,
        type: primer_soporte.content_type
      )
      resultado = SoporteParser.new(archivo).call
      pago.update_column(:datos_ocr, resultado)
    end
  rescue => e
    Rails.logger.error("AnalizarSoporteJob error (pago_id=#{pago_id}): #{e.message}")
  end
end
