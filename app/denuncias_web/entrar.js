import './pase.js';
import { captcha, config } from './comun.js';

const cfg = await config();
const form = document.getElementById('form-entrar');
const params = new URLSearchParams(location.search);
if (params.has('enviado')) { document.getElementById('enviado').hidden = false; form.hidden = true; }
if (params.has('error')) {
  document.getElementById('fallo').textContent = params.get('error') === 'captcha'
    ? 'Completa el captcha y vuelve a intentarlo.'
    : 'No se pudo entrar. El enlace puede haber vencido: pide uno nuevo.';
}
if (!cfg.cuentas) { form.hidden = true; document.getElementById('fallo').textContent = 'Las cuentas aún no están habilitadas.'; }

const token = await captcha(form.querySelector('.captcha'), cfg.turnstileSiteKey);
form.addEventListener('submit', () => { form.elements['cf-turnstile-response'].value = token(); });
