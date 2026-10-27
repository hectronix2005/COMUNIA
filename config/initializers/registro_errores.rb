# Guarda en ErrorApp los errores que nadie controló (Rails los reporta desde las peticiones y los
# trabajos). Los que Rails ya convierte en 404, 422 o similares no cuentan: solo lo que acaba en 500.
# Tampoco los de `rails runner`: quien lo lanza ya ve el error en su consola y no hay que avisar a nadie.
class RegistroDeErrores
  def report(error, handled:, severity:, context:, source: nil)
    return if handled || source == "application.runner.railties"
    return if ActionDispatch::ExceptionWrapper.status_code_for_exception(error.class.name) != 500

    ErrorApp.registrar!(error, origen: origen(context) || source)
  rescue StandardError => e
    # Sin base no se puede guardar; que el error original siga su curso.
    Rails.logger.error("RegistroDeErrores: #{e.class}: #{e.message}")
  end

  private

  def origen(context)
    if (controlador = context[:controller]).respond_to?(:action_name)
      "#{controlador.class.name}##{controlador.action_name}"
    elsif (trabajo = context[:job])
      trabajo.class.name
    end
  end
end

Rails.application.config.after_initialize { Rails.error.subscribe(RegistroDeErrores.new) }
