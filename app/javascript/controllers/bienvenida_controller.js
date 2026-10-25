import { Controller } from "@hotwired/stimulus"

// Pantalla de bienvenida: pedir permiso de avisos con un toque (iPhone solo lo permite así) e instalar
// la PWA cuando el navegador lo ofrece. La suscripción push la hace notifications_controller.
export default class extends Controller {
  static targets = ["avisos", "avisosEstado", "instalar", "instalarAyuda"]

  connect() {
    this._ofrecerInstalacion = (e) => {
      e.preventDefault()
      this.instalacion = e
      this.instalarTarget.classList.remove("d-none")
      this.instalarAyudaTarget.classList.add("d-none")
    }
    window.addEventListener("beforeinstallprompt", this._ofrecerInstalacion)

    if (window.matchMedia("(display-mode: standalone)").matches) {
      this.instalarAyudaTarget.textContent = "Ya la tienes instalada."
    }
    if (!("Notification" in window) || !("PushManager" in window)) {
      this.estadoAvisos("Este navegador no admite avisos. En iPhone, primero instala la app (paso 2) y ábrela desde el inicio.")
      this.avisosTarget.disabled = true
    } else if (Notification.permission === "granted") {
      this.estadoAvisos("Avisos activados.")
      this.avisosTarget.disabled = true
    }
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this._ofrecerInstalacion)
  }

  async activarAvisos() {
    const permiso = await Notification.requestPermission()
    if (permiso === "granted") {
      window.dispatchEvent(new CustomEvent("avisos:permitidos"))
      this.estadoAvisos("Avisos activados.")
      this.avisosTarget.disabled = true
    } else {
      this.estadoAvisos("Sin permiso no llegan avisos. Puedes activarlos luego en los ajustes del navegador.")
    }
  }

  async instalar() {
    if (!this.instalacion) return
    this.instalacion.prompt()
    await this.instalacion.userChoice
    this.instalacion = null
    this.instalarTarget.classList.add("d-none")
  }

  estadoAvisos(texto) {
    this.avisosEstadoTarget.textContent = texto
    this.avisosEstadoTarget.classList.remove("d-none")
  }
}
