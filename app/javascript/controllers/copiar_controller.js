import { Controller } from "@hotwired/stimulus"

// Copia el texto de un campo al portapapeles; si el navegador no deja, lo deja seleccionado.
export default class extends Controller {
  static targets = ["texto", "boton"]

  async copiar() {
    try {
      await navigator.clipboard.writeText(this.textoTarget.value)
      if (this.hasBotonTarget) this.botonTarget.textContent = "Copiado"
    } catch {
      this.textoTarget.select()
    }
  }
}
