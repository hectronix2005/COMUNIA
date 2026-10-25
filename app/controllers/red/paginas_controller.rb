module Red
  # Páginas informativas: cómo se calcula la confianza y la política de datos (Ley 1581 de 2012).
  class PaginasController < BaseController
    publico only: %i[como_funciona privacidad]

    def como_funciona; end

    def privacidad; end
  end
end
