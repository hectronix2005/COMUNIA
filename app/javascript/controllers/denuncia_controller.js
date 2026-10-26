import { Controller } from "@hotwired/stimulus"

// Formulario de denuncia: muestra el aviso urgente y la recompensa según la categoría, y antes de enviar
// calcula el SHA-256 de cada foto ORIGINAL (primer eslabón de la cadena de custodia; el servidor lo compara).
export default class extends Controller {
  static targets = ["categoria", "urgente", "recompensa", "fotos", "boton"]
  static values = { maxFotos: { type: Number, default: 4 }, maxBytes: { type: Number, default: 10 * 1024 * 1024 } }

  connect() {
    this.cambiarCategoria()
  }

  cambiarCategoria() {
    const c = this.categoriaTarget.value
    this.urgenteTarget.hidden = c !== "microtrafico_extorsion"
    this.recompensaTarget.hidden = c !== "ubicacion_buscado"
    this.recompensaTarget.querySelector("select").required = c === "ubicacion_buscado"
  }

  async enviar(event) {
    if (this.listo) return
    event.preventDefault()
    const fotos = [...this.fotosTarget.files]
    if (fotos.length < 1 || fotos.length > this.maxFotosValue) return alert(`Adjunta entre 1 y ${this.maxFotosValue} fotos.`)
    if (fotos.some((f) => f.size > this.maxBytesValue)) return alert("Cada foto debe pesar menos de 10 MB.")

    this.botonTarget.disabled = true
    this.botonTarget.value = "Publicando…"
    this.element.querySelectorAll('input[name="hashes[]"]').forEach((i) => i.remove())
    for (const foto of fotos) {
      const campo = document.createElement("input")
      campo.type = "hidden"
      campo.name = "hashes[]"
      campo.value = await this.sha256(foto)
      this.element.append(campo)
    }
    this.listo = true
    this.element.requestSubmit()
  }

  async sha256(archivo) {
    const digest = await crypto.subtle.digest("SHA-256", await archivo.arrayBuffer())
    return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("")
  }
}
