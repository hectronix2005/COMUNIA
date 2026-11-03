// Rastreo de las pruebas «family and friends» (config/initializers/ahoy.rb). Solo se enciende en las páginas
// cuyo layout pone <meta name="rastreo" content="on"> (layouts/application): Denuncias y la red no lo llevan.
// Se anota cada vista con el tiempo que estuvo a la vista, los clics, los envíos de formularios y los errores
// del navegador. Nunca lo escrito en un campo, y las URL van sin query string (ahí viajan los tokens).
import ahoy from "ahoy.js"

const activo = () => document.querySelector('meta[name="rastreo"]')?.content === "on"
const sinQuery = (url) => {
  try { const u = new URL(url, location.href); return u.origin === location.origin ? u.pathname : u.origin + u.pathname } catch { return null }
}
const texto = (el) => (el.getAttribute("aria-label") || el.textContent || el.value || "").replace(/\s+/g, " ").trim().slice(0, 80)

// Sin arranque automático: en Denuncias y la red (que cargan el mismo application.js) no debe abrir visita.
ahoy.configure({ visitDuration: 30, useBeacon: true, startOnReady: false })

// Tiempo en cada vista: total desde que se abrió y solo el que estuvo en pantalla (pestaña visible).
let vista = null
function cerrarVista(motivo) {
  if (!vista) return
  const ahora = performance.now()
  if (vista.desde !== null) vista.visible += ahora - vista.desde
  ahoy.track("Tiempo en vista", {
    page: vista.page, titulo: vista.titulo, motivo,
    segundos: Math.round((ahora - vista.inicio) / 1000), segundos_visible: Math.round(vista.visible / 1000)
  })
  vista = null
}
function abrirVista() {
  cerrarVista("navegó")
  if (!activo()) return
  ahoy.start()
  const page = location.pathname
  vista = { page, titulo: document.title, inicio: performance.now(), visible: 0, desde: document.hidden ? null : performance.now() }
  ahoy.trackView({ url: location.origin + page, page, pantalla: `${innerWidth}x${innerHeight}` })
}

document.addEventListener("turbo:load", abrirVista)
document.addEventListener("visibilitychange", () => {
  if (!vista) return
  if (document.hidden) {
    if (vista.desde !== null) vista.visible += performance.now() - vista.desde
    vista.desde = null
    ahoy.track("Pestaña oculta", { page: vista.page })
  } else {
    vista.desde = performance.now()
    ahoy.track("Pestaña visible", { page: vista.page })
  }
})
addEventListener("pagehide", () => cerrarVista("salió"))

document.addEventListener("click", (e) => {
  if (!activo()) return
  const el = e.target.closest("a, button, input[type=submit], input[type=button], [role=button], summary, label")
  if (!el || el.closest("[data-ahoy-skip]")) return
  ahoy.track("$click", {
    page: location.pathname, tag: el.tagName.toLowerCase(), texto: texto(el),
    id: el.id || null, href: el.href ? sinQuery(el.href) : null
  })
}, true)

document.addEventListener("submit", (e) => {
  if (!activo()) return
  const f = e.target
  ahoy.track("$submit", { page: location.pathname, id: f.id || null, accion: sinQuery(f.action), metodo: (f.querySelector("[name=_method]")?.value || f.method || "get").toUpperCase() })
}, true)

// Eventos con nombre que mandan los controladores (los pasos para activar los avisos, por ejemplo).
addEventListener("rastreo:evento", (e) => {
  if (!activo() || !e.detail?.nombre) return
  ahoy.track(String(e.detail.nombre).slice(0, 60), { page: location.pathname, ...(e.detail.datos || {}) })
})

function errorNavegador(datos) {
  if (!activo()) return
  ahoy.track("Error del navegador", { page: location.pathname, ...datos })
}
addEventListener("error", (e) => {
  if (e.target && e.target !== window && e.target.tagName) {
    errorNavegador({ tipo: "recurso", mensaje: `No cargó ${e.target.tagName.toLowerCase()}`, archivo: sinQuery(e.target.src || e.target.href || "") })
  } else {
    errorNavegador({ tipo: "script", mensaje: String(e.message).slice(0, 300), archivo: sinQuery(e.filename || ""), linea: e.lineno, columna: e.colno })
  }
}, true)
addEventListener("unhandledrejection", (e) => {
  errorNavegador({ tipo: "promesa", mensaje: String(e.reason?.message || e.reason).slice(0, 300) })
})
document.addEventListener("turbo:fetch-request-error", (e) => {
  errorNavegador({ tipo: "red", mensaje: "Falló una petición (sin conexión o el servidor no respondió)", archivo: sinQuery(e.detail?.request?.url?.href || "") })
})
