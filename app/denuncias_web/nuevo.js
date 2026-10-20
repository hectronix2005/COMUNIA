import './pase.js';
import { captcha, config, el, enviar } from './comun.js';
import { gastarPase, paseGuardado } from './pase.js';

const cfg = await config();
const form = document.getElementById('form-reporte');
const error = form.querySelector('.error');
const selCategoria = form.elements.categoria;
const selRecompensa = form.elements.recompensa_id;

selCategoria.append(el('option', { value: '', texto: 'Elige…' }),
  ...Object.entries(cfg.categorias).map(([v, t]) => el('option', { value: v, texto: t })));
form.elements.localidad.append(el('option', { value: '', texto: 'Elige…' }),
  ...cfg.localidades.map((l) => el('option', { value: l, texto: l })));

const recompensas = await (await fetch('/api/recompensas')).json();
selRecompensa.append(...recompensas.map((r) => el('option', { value: r.id, texto: `${r.titulo} (${r.entidad})` })));

function alCambiarCategoria() {
  const c = selCategoria.value;
  document.getElementById('aviso-urgente').hidden = c !== 'microtrafico_extorsion';
  document.getElementById('campo-recompensa').hidden = c !== 'ubicacion_buscado';
  selRecompensa.required = c === 'ubicacion_buscado';
}
selCategoria.addEventListener('change', alCambiarCategoria);

const preseleccion = new URLSearchParams(location.search).get('recompensa');
if (preseleccion && recompensas.some((r) => r.id === preseleccion)) {
  selCategoria.value = 'ubicacion_buscado';
  selRecompensa.value = preseleccion;
  alCambiarCategoria();
}

if (cfg.cuentas) {
  const cuenta = await (await fetch('/api/cuenta')).json();
  if (cuenta.alias) {
    document.getElementById('mi-alias').textContent = `@${cuenta.alias} (tu correo nunca se muestra)`;
    document.getElementById('publicar-como').hidden = false;
  }
}

document.getElementById('aviso-sello').hidden = !paseGuardado();
document.getElementById('sello-donde').textContent = cfg.selloPublico
  ? 'El sello se verá en el muro junto a tu denuncia.'
  : 'Mientras la red sea pequeña, el sello solo lo ve la autoridad que recibe la denuncia, no el público, para que no te puedan identificar por él.';

if (cfg.disponible === false) {
  form.hidden = true;
  document.getElementById('no-disponible').hidden = false;
}

const token = await captcha(form.querySelector('.captcha'), cfg.turnstileSiteKey);

async function sha256(archivo) {
  const digest = await crypto.subtle.digest('SHA-256', await archivo.arrayBuffer());
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

form.addEventListener('submit', async (ev) => {
  ev.preventDefault();
  error.textContent = '';
  const fotos = [...form.elements.fotos.files];
  if (fotos.length < 1 || fotos.length > cfg.maxFotos) return (error.textContent = `Adjunta entre 1 y ${cfg.maxFotos} fotos.`);
  if (fotos.some((f) => f.size > cfg.maxBytesFoto)) return (error.textContent = 'Cada foto debe pesar menos de 10 MB.');

  const boton = document.getElementById('enviar');
  boton.disabled = true;
  boton.textContent = 'Publicando…';
  try {
    const datos = new FormData(form);
    datos.delete('fotos');
    if (selCategoria.value !== 'ubicacion_buscado') datos.delete('recompensa_id');
    // El hash del ORIGINAL se calcula aquí, antes de subir: es el primer eslabón de la cadena de custodia.
    for (const f of fotos) {
      datos.append('fotos[]', f);
      datos.append('hashes[]', await sha256(f));
    }
    datos.set('cf-turnstile-response', token());
    const pase = paseGuardado();
    if (pase) datos.set('pase', pase);
    const r = await enviar('/api/reportes', { method: 'POST', body: datos });
    const j = await r.json();
    if (!r.ok) throw new Error(j.error ?? 'No se pudo publicar');
    if (j.sello) gastarPase(); // aplicado, inválido o ya usado: no se vuelve a enviar
    document.getElementById('resultado-sello').textContent = {
      aplicado: j.selloPublico
        ? 'Tu denuncia lleva el sello de denunciante verificado.'
        : 'Tu denuncia quedó verificada. Por ahora el sello solo lo ve la autoridad, para protegerte.',
      pase_invalido: 'El pase de tu comunidad no era válido: tu denuncia se publicó sin sello.',
      pase_usado: 'Ese pase de tu comunidad ya se había usado: tu denuncia se publicó sin sello.',
    }[j.sello] ?? '';
    form.hidden = true;
    document.getElementById('codigo').textContent = j.codigo;
    document.getElementById('listo').hidden = false;
  } catch (e) {
    error.textContent = e.message;
    window.turnstile?.reset();
  } finally {
    boton.disabled = false;
    boton.textContent = 'Publicar denuncia';
  }
});
