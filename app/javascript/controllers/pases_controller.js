import { Controller } from "@hotwired/stimulus"
import { RSABSSA } from "@cloudflare/blindrsa-ts"

// Monedero de pases anónimos para DENUNCIAPP (contrato v2, 19-oct-2026).
// - Cada semana ISO, en la primera visita y a una hora al azar de la sesión, un
//   miembro activo pide exactamente 4 pases, los vaya a usar o no: así pedir
//   pases no delata la intención de denunciar. Un pase gastado no se repone
//   hasta la semana siguiente.
// - Pase = {kid, msg, firma} en base64url; msg es la salida de Prepare() (64 bytes).
//   En la URL va como #pase=base64url(JSON del pase).
// - El clic en «Denuncias» no pide nada al servidor: saca un pase ya guardado.
const CLAVE = "comunia.pases"
const POR_SEMANA = 4
const suite = RSABSSA.SHA384.PSS.Randomized()

const b64 = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
const deB64 = (texto) => Uint8Array.from(atob(texto.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0))

export default class extends Controller {
  static values = { usuario: String, activo: Boolean, semana: String }

  connect() {
    const monedero = this.leer()
    if (monedero.usuario !== this.usuarioValue) this.guardar({ usuario: this.usuarioValue, semana: null, pases: [] })
    if (this.activoValue && this.leer().semana !== this.semanaValue) {
      this.temporizador = setTimeout(() => this.recargar(), 5000 + Math.random() * 55000)
    }
  }

  disconnect() {
    clearTimeout(this.temporizador)
  }

  // Entrada «Denuncias»: abre DENUNCIAPP con un pase en el fragmento, o sin él si no hay.
  abrir(event) {
    const enlace = event.currentTarget
    const monedero = this.leer()
    const ahora = Date.now()
    monedero.pases = monedero.pases.filter((p) => Date.parse(p.hasta) > ahora)
    const pase = monedero.pases.pop() // el más antiguo: el primero que caduca
    this.guardar(monedero)
    if (!pase) return

    event.preventDefault()
    const { kid, msg, firma } = pase
    const a = document.createElement("a")
    a.href = enlace.href.split("#")[0] + "#pase=" + b64(new TextEncoder().encode(JSON.stringify({ kid, msg, firma })))
    a.rel = "noreferrer noopener"
    a.referrerPolicy = "no-referrer"
    a.click()
  }

  vaciar() {
    try { localStorage.removeItem(CLAVE) } catch {}
  }

  async recargar() {
    try {
      const respuesta = await fetch("/pases/claves.json", { credentials: "same-origin" })
      if (!respuesta.ok) return
      const ahora = Date.now()
      const clave = (await respuesta.json()).claves
        .find((c) => Date.parse(c.desde) <= ahora && ahora < Date.parse(c.hasta))
      if (!clave) return

      const publica = await crypto.subtle.importKey("jwk", { kty: "RSA", n: clave.n, e: clave.e, alg: "PS384", ext: true },
        { name: "RSA-PSS", hash: "SHA-384" }, true, ["verify"])
      const nuevos = []
      let semanaCerrada = false
      for (let i = 0; i < POR_SEMANA; i++) {
        const resultado = await this.pedirPase(clave, publica)
        if (resultado === "fin") { semanaCerrada = true; break }
        if (!resultado) break
        nuevos.push(resultado)
      }
      if (nuevos.length === POR_SEMANA) semanaCerrada = true

      const monedero = this.leer()
      const vigentes = monedero.pases.filter((p) => Date.parse(p.hasta) > ahora)
      monedero.pases = [...nuevos, ...vigentes].slice(0, POR_SEMANA)
      if (semanaCerrada) monedero.semana = this.semanaValue
      this.guardar(monedero)
    } catch {
      // Sin pases esta vez; se reintenta en la próxima visita.
    }
  }

  // Un pase nuevo, null si falló (se reintenta otro día) o "fin" si el servidor
  // dice que esta semana no hay más (cupo gastado o miembro no activo).
  async pedirPase(clave, publica) {
    const msg = suite.prepare(crypto.getRandomValues(new Uint8Array(32)))
    const { blindedMsg, inv } = await suite.blind(publica, msg)
    const respuesta = await fetch("/pases/firmar", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ kid: clave.kid, cegado: b64(blindedMsg) })
    })
    if (respuesta.status === 429 || respuesta.status === 403) return "fin"
    if (!respuesta.ok) return null

    const { firma_cegada } = await respuesta.json()
    const firma = await suite.finalize(publica, msg, deB64(firma_cegada), inv)
    if (!(await suite.verify(publica, firma, msg))) return null
    return { kid: clave.kid, msg: b64(msg), firma: b64(firma), hasta: clave.hasta }
  }

  leer() {
    try {
      const datos = JSON.parse(localStorage.getItem(CLAVE))
      if (datos && Array.isArray(datos.pases)) return datos
    } catch {}
    return { usuario: null, semana: null, pases: [] }
  }

  guardar(monedero) {
    try { localStorage.setItem(CLAVE, JSON.stringify(monedero)) } catch {}
  }
}
