import { Controller } from "@hotwired/stimulus"

// Modo invitado: la demostración solo se mira. Antes de enviar algo que guardaría (un formulario que no es GET,
// un enlace con data-turbo-method o un fetch que escribe) se explica cómo participar. El servidor lo frena igual
// (ApplicationController#solo_lectura_para_invitado); esto evita que la acción se pierda sin explicación.
const LIBRES = /(?:^|\/)(?:demo|logout)$/

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.interceptar = this.interceptar.bind(this)
    document.addEventListener("submit", this.interceptar, true)
    document.addEventListener("click", this.interceptar, true)
    envolverFetch()
  }

  disconnect() {
    document.removeEventListener("submit", this.interceptar, true)
    document.removeEventListener("click", this.interceptar, true)
  }

  interceptar(event) {
    const elemento = event.type === "submit" ? event.target : event.target.closest?.("[data-turbo-method]")
    if (!elemento || elemento.closest("[data-invitado-libre]")) return
    const destino = event.type === "submit" ? elemento.action : elemento.href
    if (destino && LIBRES.test(new URL(destino, window.location.href).pathname)) return
    const metodo = event.type === "submit" ? (event.submitter?.getAttribute("formmethod") || elemento.method) : elemento.dataset.turboMethod
    if (!metodo || metodo.toLowerCase() === "get") return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.mostrar()
  }

  mostrar() {
    window.bootstrap.Modal.getOrCreateInstance(this.modalTarget).show()
  }
}

// Las reacciones del chat, leer avisos y otros fetch que escriben: con el aviso del invitado en la página, no
// salen y se abre la ventana. Salir (demo, logout) sí sale.
function envolverFetch() {
  if (window.fetch.deInvitado) return
  const original = window.fetch
  const envuelto = function (recurso, opciones = {}) {
    const aviso = document.querySelector("[data-controller~='invitado']")
    const metodo = (opciones.method || recurso?.method || "GET").toUpperCase()
    const ruta = new URL(recurso?.url || recurso, window.location.href).pathname
    if (aviso && !["GET", "HEAD"].includes(metodo) && !LIBRES.test(ruta)) {
      aviso.dispatchEvent(new CustomEvent("invitado:bloqueado"))
      return Promise.resolve(new Response(null, { status: 403 }))
    }
    return original.call(window, recurso, opciones)
  }
  envuelto.deInvitado = true
  window.fetch = envuelto
}
