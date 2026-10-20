// Pase anónimo de COMUNIA. Llega en el fragmento (#pase=…), que nunca viaja al servidor. Se borra de la
// barra en cuanto carga la página y se guarda solo en sessionStorage: muere al cerrar la pestaña.
const CLAVE = 'denunciapp.pase';

if (location.hash.startsWith('#pase=')) {
  const valor = location.hash.slice('#pase='.length);
  history.replaceState(null, '', location.pathname + location.search);
  if (/^[A-Za-z0-9_-]{1,4096}$/.test(valor)) {
    try { sessionStorage.setItem(CLAVE, valor); } catch { /* sin almacenamiento: se denuncia sin sello */ }
  }
}

export function paseGuardado() {
  try { return sessionStorage.getItem(CLAVE); } catch { return null; }
}

export function gastarPase() {
  try { sessionStorage.removeItem(CLAVE); } catch { /* nada */ }
}
