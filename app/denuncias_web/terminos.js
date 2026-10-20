import './pase.js';
import { config } from './comun.js';

const { contacto } = await config();
if (contacto) document.getElementById('contacto').textContent = `Contacto del responsable del tratamiento: ${contacto}`;
