// Utilidades compartidas. Todo texto de usuario se pinta con textContent, nunca con innerHTML.

// Token CSRF de Rails (lo pone la página en <meta name="csrf-token">) para todo POST.
export function csrf() {
  return document.querySelector('meta[name="csrf-token"]')?.content ?? '';
}

/** fetch del propio sitio con el token CSRF y sin Referer. */
export function enviar(url, opciones = {}) {
  const headers = new Headers(opciones.headers);
  headers.set('X-CSRF-Token', csrf());
  return fetch(url, { ...opciones, headers, credentials: 'same-origin', referrerPolicy: 'no-referrer' });
}

export async function config() {
  const r = await fetch('/api/config');
  return r.json();
}

export function el(etiqueta, props = {}, ...hijos) {
  const nodo = document.createElement(etiqueta);
  for (const [k, v] of Object.entries(props)) {
    if (k === 'texto') nodo.textContent = v;
    else if (k.startsWith('on')) nodo.addEventListener(k.slice(2), v);
    else nodo.setAttribute(k, v);
  }
  for (const h of hijos) if (h) nodo.append(h);
  return nodo;
}

let scriptTurnstile;
/** Pinta el captcha si el servidor tiene Turnstile configurado; si no (desarrollo), no hace nada. */
export async function captcha(contenedor, siteKey) {
  if (!siteKey) return () => '';
  scriptTurnstile ??= new Promise((ok) => {
    const s = el('script', { src: 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit' });
    s.onload = ok;
    document.head.append(s);
  });
  await scriptTurnstile;
  const id = window.turnstile.render(contenedor, { sitekey: siteKey });
  return () => window.turnstile.getResponse(id) ?? '';
}

/** La API solo da la fecha (AAAA-MM-DD, Bogotá): la hora exacta no es pública. */
export function cuando(fecha) {
  const hoy = new Date(Date.now() - 5 * 3_600_000).toISOString().slice(0, 10);
  const dias = Math.round((Date.parse(hoy) - Date.parse(fecha)) / 86_400_000);
  if (dias <= 0) return 'hoy';
  if (dias === 1) return 'ayer';
  return `hace ${dias} días`;
}

export const TEXTO_SELLO = '✓ Denunciante verificado por una comunidad certificada';
