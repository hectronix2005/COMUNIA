import './pase.js';
import { config, cuando, el, enviar } from './comun.js';

const cfg = await config();
const cuenta = await (await fetch('/api/cuenta')).json();
if (!cuenta.sesion) location.replace('/entrar');


const formAlias = document.getElementById('form-alias');
if (!cuenta.alias) document.getElementById('elegir-alias').hidden = false;
else document.getElementById('saludo').textContent = `Publicas como @${cuenta.alias}.`;

formAlias.addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const r = await enviar('/api/cuenta/alias', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ alias: formAlias.elements.alias.value }),
  });
  if (r.ok) location.reload();
  else formAlias.querySelector('.error').textContent = (await r.json()).error;
});

async function retirar(id, boton) {
  boton.disabled = true;
  const r = await enviar(`/api/cuenta/reportes/${encodeURIComponent(id)}/retirar`, { method: 'POST' });
  if (r.ok) location.reload();
  else boton.disabled = false;
}

const mias = await (await fetch('/api/cuenta/reportes')).json();
const lista = document.getElementById('mias');
if (!mias.length) lista.append(el('p', { texto: 'Aún no has publicado con tu alias.' }));
for (const r of mias) {
  const boton = r.estado !== 'retirado' ? el('button', { class: 'secundario', texto: 'Retirar' }) : null;
  boton?.addEventListener('click', () => retirar(r.id, boton));
  lista.append(el('article', { class: 'tarjeta' },
    el('p', { class: 'meta', texto: `${cfg.categorias[r.categoria] ?? r.categoria} · ${r.localidad} · ${cuando(r.fecha)} · ${r.estado}` }),
    el('h3', { texto: r.titulo }),
    boton));
}
