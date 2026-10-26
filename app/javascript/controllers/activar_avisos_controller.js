import { Controller } from "@hotwired/stimulus"

// Tarjeta del panel para activar los avisos en este teléfono con un toque (iPhone solo pide permiso así, y solo
// con la app instalada). Si ya están activados, no sale; «Ahora no» la esconde dos semanas en este navegador.
// La suscripción push la hace notifications_controller al recibir «avisos:permitidos».
const AHORA_NO = "avisos_ahora_no"
const DOS_SEMANAS = 14 * 24 * 60 * 60 * 1000

export default class extends Controller {
  static targets = ["boton", "estado"]

  connect() {
    if (this.pospuesta()) return
    const iphone = /iPhone|iPad|iPod/.test(navigator.userAgent)
    const instalada = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone

    if (!("Notification" in window) || !("PushManager" in window)) {
      if (!iphone || instalada) return
      this.decir("En iPhone, primero instala la app: toca Compartir y luego «Añadir a pantalla de inicio». Ábrela desde ahí y activa los avisos.")
      this.botonTarget.classList.add("d-none")
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
    try { return Date.now() - Number(localStorage.getItem(AHORA_NO) || 0) < DOS_SEMANAS } catch (_) { return false }
  }

  decir(texto) {
    this.estadoTarget.textContent = texto
    this.estadoTarget.classList.remove("d-none")
  }
}
