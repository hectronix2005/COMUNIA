import { Controller } from "@hotwired/stimulus"

// Tarjeta del panel para activar los avisos en este teléfono con un toque (iPhone solo pide permiso así, y solo
// con la app instalada: en Safari enseña los tres pasos para instalarla). Si ya están activados, no sale;
// «Ahora no» la esconde tres días en este navegador. La suscripción push la hace notifications_controller al
// recibir «avisos:permitidos». Cada paso se anota en el rastreo para ver dónde se queda la gente.
const AHORA_NO = "avisos_ahora_no"
const TRES_DIAS = 3 * 24 * 60 * 60 * 1000

export default class extends Controller {
  static targets = ["boton", "estado", "normal", "iphone"]

  connect() {
    const iphone = /iPhone|iPad|iPod/.test(navigator.userAgent)
    const instalada = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true
    const admite = ("Notification" in window) && ("PushManager" in window)
    this.anotarUnaVez("Avisos: tarjeta", {
      iphone, instalada, admite, permiso: admite ? Notification.permission : "sin soporte", pospuesta: this.pospuesta()
    })
    if (this.pospuesta()) return

    if (!admite) {
      if (!iphone || instalada) return
      this.normalTarget.classList.add("d-none")
      this.iphoneTarget.classList.remove("d-none")
    } else if (Notification.permission === "granted") {
      return
    } else if (Notification.permission === "denied") {
      this.decir("Los avisos están bloqueados en este navegador. Actívalos en sus ajustes (el candado junto a la dirección) y vuelve a entrar.")
      this.botonTarget.classList.add("d-none")
    }
    this.element.classList.remove("d-none")
  }

  async activar() {
    const permiso = await Notification.requestPermission()
    this.anotar("Avisos: permiso", { resultado: permiso })
    if (permiso === "granted") {
      window.dispatchEvent(new CustomEvent("avisos:permitidos"))
      this.decir("Listo: los avisos llegarán a este teléfono.")
      this.botonTarget.classList.add("d-none")
    } else {
      this.decir("Sin permiso no llegan avisos. Puedes activarlos luego en los ajustes del navegador.")
    }
  }

  ahoraNo() {
    try { localStorage.setItem(AHORA_NO, String(Date.now())) } catch (_) {}
    this.element.classList.add("d-none")
  }

  pospuesta() {
    try { return Date.now() - Number(localStorage.getItem(AHORA_NO) || 0) < TRES_DIAS } catch (_) { return false }
  }

  decir(texto) {
    this.estadoTarget.textContent = texto
    this.estadoTarget.classList.remove("d-none")
  }

  // La tarjeta sale en cada visita al panel: al rastreo, una vez por sesión del navegador.
  anotarUnaVez(nombre, datos) {
    try {
      if (sessionStorage.getItem("avisos_tarjeta")) return
      sessionStorage.setItem("avisos_tarjeta", "1")
    } catch (_) {}
    this.anotar(nombre, datos)
  }

  anotar(nombre, datos) {
    window.dispatchEvent(new CustomEvent("rastreo:evento", { detail: { nombre, datos } }))
  }
}
