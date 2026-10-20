import './pase.js';
import { TEXTO_SELLO, captcha, config, cuando, el, enviar } from './comun.js';

const cfg = await config();
const muro = document.getElementById('muro');
const mas = document.getElementById('mas');
let antes;

function tarjeta(r) {
  return el('article', { class: 'tarjeta' },
    el('p', { class: 'meta', texto: `${cfg.categorias[r.categoria] ?? r.categoria} · ${r.localidad} · ${cuando(r.fecha)} · ${r.alias ? `por @${r.alias}` : 'anónimo'}` }),
    r.verificada ? el('p', { class: 'sello', texto: TEXTO_SELLO }) : null,
    el('h3', { texto: r.titulo }),
    el('p', { class: 'lugar', texto: r.lugar }),
    el('p', { class: 'descripcion', texto: r.descripcion }),
    el('div', { class: 'fotos' }, ...r.fotos.map((src) => el('a', { href: src, target: '_blank', rel: 'noopener' },
      el('img', { src, alt: 'Foto de la denuncia', loading: 'lazy' })))),
    el('button', { class: 'enlace', texto: 'Solicitar retiro', onclick: () => abrirRetiro(r.id) }),
  );
}

async function cargar() {
  const r = await fetch(`/api/reportes${antes ? `?antes=${antes}` : ''}`);
  const lista = await r.json();
  if (!antes && lista.length === 0) muro.append(el('p', { texto: 'Aún no hay denuncias publicadas.' }));
  for (const rep of lista) muro.append(tarjeta(rep));
  antes = lista.at(-1)?.n;
  mas.hidden = lista.length < 20;
}
mas.addEventListener('click', cargar);

async function cargarRecompensas() {
  const lista = await (await fetch('/api/recompensas')).json();
  if (!lista.length) return;
  document.getElementById('recompensas').hidden = false;
  document.getElementById('lista-recompensas').append(...lista.map((r) =>
    el('article', { class: 'tarjeta' },
      el('p', { class: 'meta', texto: r.entidad }),
      el('h3', { texto: r.titulo }),
      el('p', { texto: `Recompensa: ${r.montoTexto}` }),
      el('p', {}, el('a', { href: r.fuenteUrl, target: '_blank', rel: 'noopener noreferrer', texto: 'Fuente oficial' })),
      el('a', { class: 'boton', href: `/nuevo?recompensa=${encodeURIComponent(r.id)}`, texto: 'Tengo información' }),
    )));
}

// Solicitud de retiro
const dialogo = document.getElementById('dialogo-retiro');
const formRetiro = document.getElementById('form-retiro');
let retiroId;
let tokenRetiro = () => '';
async function abrirRetiro(id) {
  retiroId = id;
  formRetiro.reset();
  formRetiro.querySelector('.error').textContent = '';
  dialogo.showModal();
  const caja = formRetiro.querySelector('.captcha');
  if (!caja.hasChildNodes()) tokenRetiro = await captcha(caja, cfg.turnstileSiteKey);
}
formRetiro.addEventListener('submit', async (ev) => {
  if (ev.submitter?.value !== 'enviar') return;
  ev.preventDefault();
  const datos = Object.fromEntries(new FormData(formRetiro));
  const r = await enviar(`/api/reportes/${encodeURIComponent(retiroId)}/retiro`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...datos, 'cf-turnstile-response': tokenRetiro() }),
  });
  if (r.ok) { dialogo.close(); alertaSuave('Solicitud enviada. El operador la revisará.'); }
  else formRetiro.querySelector('.error').textContent = (await r.json()).error ?? 'No se pudo enviar';
});

// Seguimiento
const formSeg = document.getElementById('form-seguimiento');
const salida = document.getElementById('resultado-seguimiento');
async function seguimiento(accion) {
  const codigo = new FormData(formSeg).get('codigo');
  const r = await enviar('/api/seguimiento', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ codigo, accion }),
  });
  const j = await r.json();
  salida.textContent = r.ok ? `«${j.titulo ?? 'Tu denuncia'}»: ${j.estado}` : j.error;
}
formSeg.addEventListener('submit', (ev) => { ev.preventDefault(); seguimiento(); });
document.getElementById('retirar-propio').addEventListener('click', () => formSeg.reportValidity() && seguimiento('retirar'));

function alertaSuave(texto) {
  salida.textContent = texto;
  salida.scrollIntoView({ behavior: 'smooth' });
}

async function enlaceCuenta() {
  if (!cfg.cuentas) return;
  const a = document.getElementById('enlace-cuenta');
  const cuenta = await (await fetch('/api/cuenta')).json();
  if (cuenta.sesion) { a.textContent = cuenta.alias ? `@${cuenta.alias}` : 'Mi cuenta'; a.href = '/cuenta'; }
  a.hidden = false;
}

await Promise.all([cargar(), cargarRecompensas(), enlaceCuenta()]);
