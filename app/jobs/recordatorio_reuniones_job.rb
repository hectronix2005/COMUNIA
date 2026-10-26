# Cada hora: a las reuniones convocadas que empiezan en las próximas 24 h y aún no tuvieron recordatorio, se
# les manda uno (una sola vez por reunión).
class RecordatorioReunionesJob < ApplicationJob
  queue_as :default

  def perform
    Reunion.convocada.where(recordatorio_enviado_at: nil, inicio: Time.current..24.hours.from_now).find_each do |reunion|
      next unless reunion.logia.modulo?(:reuniones)

      reunion.update_column(:recordatorio_enviado_at, Time.current)
      NotificarReunionJob.perform_now(reunion.id, "recordatorio")
    end
  end
end
