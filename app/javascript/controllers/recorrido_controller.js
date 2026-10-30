import { Controller } from "@hotwired/stimulus"

// Recorrido guiado, pantalla a pantalla. Los pasos vienen del servidor (RecorridoHelper); el paso en curso se guarda
// en sessionStorage y se cambia de pantalla con Turbo. Resalta el elemento [data-recorrido=<foco>] oscureciendo el
// resto; si no está, el globo sale centrado (o se salta el paso si es opcional). Al terminar u omitir se avisa al
// servidor para que no vuelva a arrancar solo.
const CLAVE = "comunia-recorrido"
const HECHO = "comunia-recorrido-hecho"

export default class extends Controller {
  static values = { pasos: Array, automatico: Boolean, marcarUrl: String }

  connect() {
    this.reubicar = this.reubicar.bind(this)
    this.teclas = this.teclas.bind(this)
    this.antesDeGuardar = () => this.cerrar()
    document.addEventListener("turbo:before-cache", this.antesDeGuardar)

    const estado = this.leer()
    if (estado) {
      this.mostrar(estado)
    } else if (this.automaticoValue && !this.guardado(HECHO) && this.enRuta(this.pasosValue[0])) {
      this.mostrar({ paso: 0, dir: 1 })
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.antesDeGuardar)
    this.cerrar()
  }

  // Botón «Repetir el recorrido» de la Guía y del inicio.
  empezar(event) {
    event?.preventDefault()
    this.ir(0, 1)
  }

  ir(indice, dir) {
    if (indice < 0) indice = 0
    if (indice >= this.pasosValue.length) return this.terminar()
    const estado = { paso: indice, dir }
    this.escribir(estado)
    this.mostrar(estado)
  }

  mostrar(estado) {
    const paso = this.pasosValue[estado.paso]
    if (!paso) return this.olvidar()

    if (!this.enRuta(paso)) {
      // Si al visitar la pantalla se acabó en otra (una redirección), el paso se muestra igual, centrado.
      if (estado.visitado !== estado.paso) {
        this.escribir({ ...estado, visitado: estado.paso })
        this.cerrar()
        return this.visitar(paso.ruta)
      }
    }

    const objetivo = this.buscar(paso.foco)
    if (!objetivo && paso.opcional) return this.ir(estado.paso + (estado.dir || 1), estado.dir || 1)

    this.indice = estado.paso
    this.objetivo = objetivo
    this.pintar(paso)
    if (objetivo) {
      objetivo.style.scrollMarginTop = "88px"
      const alto = objetivo.getBoundingClientRect().height
      objetivo.scrollIntoView({ block: alto > window.innerHeight * 0.6 ? "start" : "center", behavior: "instant" })
    }
    this.reubicar()
  }

  siguiente() { this.ir(this.indice + 1, 1) }
  atras() { this.ir(this.indice - 1, -1) }

  terminar() {
    this.olvidar()
    this.cerrar()
    this.guardar(HECHO)
    if (!this.marcarUrlValue) return
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.marcarUrlValue, {
      method: "PATCH",
      headers: { "X-CSRF-Token": token, "Accept": "application/json" },
      credentials: "same-origin"
    }).catch(() => {})
  }

  // ── Dibujo ─────────────────────────────────────────────────

  pintar(paso) {
    this.cerrar()
    const total = this.pasosValue.length
    const ultimo = this.indice === total - 1

    const raiz = this.crear("div", "recorrido")
    raiz.setAttribute("role", "dialog")
    raiz.setAttribute("aria-modal", "true")
    raiz.setAttribute("aria-labelledby", "recorrido-titulo")
    if (!this.objetivo) raiz.classList.add("recorrido-sin-foco")

    raiz.append(this.crear("div", "recorrido-capa"))
    this.foco = this.crear("div", "recorrido-foco")
    raiz.append(this.foco)

    const globo = this.crear("div", "recorrido-globo")
    globo.append(this.crear("div", "recorrido-paso", `Recorrido · paso ${this.indice + 1} de ${total}`))
    const titulo = this.crear("h2", null, paso.titulo)
    titulo.id = "recorrido-titulo"
    globo.append(titulo, this.crear("p", null, paso.texto))

    const progreso = this.crear("div", "recorrido-progreso")
    for (let i = 0; i < total; i++) progreso.append(this.crear("i", i <= this.indice ? "on" : null))
    globo.append(progreso)

    const botones = this.crear("div", "recorrido-botones")
    const omitir = this.boton("recorrido-omitir", ultimo ? "Cerrar" : "Omitir", () => this.terminar())
    botones.append(omitir)
    if (this.indice > 0) botones.append(this.boton("btn btn-sm recorrido-atras", "Atrás", () => this.atras()))
    const seguir = this.boton("btn btn-sm btn-acento", ultimo ? "Terminar" : "Siguiente", () => this.siguiente())
    botones.append(seguir)
    globo.append(botones)
    raiz.append(globo)

    this.globo = globo
    this.raiz = raiz
    document.body.append(raiz)
    window.addEventListener("resize", this.reubicar)
    window.addEventListener("scroll", this.reubicar, { passive: true })
    document.addEventListener("keydown", this.teclas)
    seguir.focus({ preventScroll: true })
  }

  reubicar() {
    if (!this.raiz) return
    const ancho = window.innerWidth
    const alto = window.innerHeight
    const g = this.globo
    g.style.top = g.style.bottom = g.style.left = ""

    const r = this.objetivo?.getBoundingClientRect()
    if (!r || (r.width === 0 && r.height === 0)) {
      this.foco.hidden = true
      g.style.left = `${Math.max(12, (ancho - g.offsetWidth) / 2)}px`
      g.style.top = `${Math.max(12, (alto - g.offsetHeight) / 2)}px`
      return
    }

    const m = 8
    const arriba = Math.max(r.top - m, 6)
    const izquierda = Math.max(r.left - m, 6)
    const abajo = Math.min(r.bottom + m, alto - 6)
    const derecha = Math.min(r.right + m, ancho - 6)
    this.foco.hidden = false
    Object.assign(this.foco.style, {
      top: `${arriba}px`, left: `${izquierda}px`,
      width: `${Math.max(derecha - izquierda, 0)}px`, height: `${Math.max(abajo - arriba, 0)}px`
    })

    const gh = g.offsetHeight
    const gw = g.offsetWidth
    if (ancho < 576) {
      // En el teléfono el globo va como hoja, arriba o abajo según dónde quede el elemento resaltado.
      g.style.left = "12px"
      if (r.top + r.height / 2 > alto / 2) g.style.top = "12px"
      else g.style.bottom = "calc(12px + env(safe-area-inset-bottom))"
      return
    }
    g.style.left = `${Math.min(Math.max(r.left, 16), ancho - gw - 16)}px`
    const centrado = `${Math.min(Math.max(arriba, 16), alto - gh - 16)}px`
    if (alto - abajo >= gh + 16) g.style.top = `${abajo + 12}px`
    else if (arriba >= gh + 16) g.style.top = `${arriba - gh - 12}px`
    // Elemento alto (el chat, una tabla): el globo va a su lado para no taparlo.
    else if (ancho - derecha >= gw + 24) Object.assign(g.style, { left: `${derecha + 12}px`, top: centrado })
    else if (izquierda >= gw + 24) Object.assign(g.style, { left: `${izquierda - gw - 12}px`, top: centrado })
    else g.style.bottom = "16px"
  }

  teclas(event) {
    if (event.key === "Escape") this.terminar()
    else if (event.key === "ArrowRight") this.siguiente()
    else if (event.key === "ArrowLeft" && this.indice > 0) this.atras()
  }

  cerrar() {
    window.removeEventListener("resize", this.reubicar)
    window.removeEventListener("scroll", this.reubicar)
    document.removeEventListener("keydown", this.teclas)
    this.raiz?.remove()
    this.raiz = this.globo = this.foco = null
  }

  // ── Ayudantes ──────────────────────────────────────────────

  buscar(foco) {
    const el = foco && document.querySelector(`[data-recorrido="${CSS.escape(foco)}"]`)
    if (!el) return null
    const r = el.getBoundingClientRect()
    return r.width > 0 && r.height > 0 ? el : null
  }

  enRuta(paso) {
    if (!paso) return false
    const limpia = (ruta) => ruta.replace(/\/+$/, "") || "/"
    return limpia(new URL(paso.ruta, window.location.origin).pathname) === limpia(window.location.pathname)
  }

  visitar(ruta) {
    if (window.Turbo) window.Turbo.visit(ruta)
    else window.location.href = ruta
  }

  crear(etiqueta, clase, texto) {
    const el = document.createElement(etiqueta)
    if (clase) el.className = clase
    if (texto) el.textContent = texto
    return el
  }

  boton(clase, texto, accion) {
    const b = this.crear("button", clase, texto)
    b.type = "button"
    b.addEventListener("click", accion)
    return b
  }

  leer() {
    try { return JSON.parse(sessionStorage.getItem(CLAVE)) } catch { return null }
  }

  escribir(estado) {
    try { sessionStorage.setItem(CLAVE, JSON.stringify(estado)) } catch {}
  }

  olvidar() {
    try { sessionStorage.removeItem(CLAVE) } catch {}
  }

  guardar(clave) {
    try { sessionStorage.setItem(clave, "1") } catch {}
  }

  guardado(clave) {
    try { return sessionStorage.getItem(clave) === "1" } catch { return false }
  }
}
