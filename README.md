# COMUNIA

Plataforma web multi-tenant para la gestión integral de talleres masónicos: miembros, cargos, tesorería, hospitalia (fondo de apoyo), biblioteca, marketplace interno y comunicación por chat.

Construida sobre **Ruby on Rails 8**, PostgreSQL, Hotwire (Turbo + Stimulus) y Bootstrap 5.

---

## Tabla de contenidos

- [Características](#características)
- [Stack técnico](#stack-técnico)
- [Arquitectura multi-tenant](#arquitectura-multi-tenant)
- [Roles y cargos](#roles-y-cargos)
- [Requisitos](#requisitos)
- [Puesta en marcha](#puesta-en-marcha)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Scripts útiles](#scripts-útiles)
- [Despliegue](#despliegue)

---

## Características

### Módulo de miembros
- Ficha completa por miembro (número, cédula, grado, estado, aliases).
- Historial de estados (activo, quite, irregular temporal, irregular permanente) con fechas de vigencia.
- **Cargos** (Tesorero, Hospitalario, Venerable Maestro, etc.) con períodos `desde`–`hasta`.
- **Familiares** (esposa, hijos…) con fechas de cumpleaños.

### Módulo de tesorería — _solo cargo Tesorero + admins_
- Conceptos de cobro, períodos, generación masiva de cobros.
- Carga de soportes de pago (OCR + validación manual).
- Confirmación o rechazo de pagos, cortes de conciliación.

### Módulo de Hospitalia — _solo cargo Hospitalario + admins_
- Recaudos y gastos con soporte adjunto (PDF/imagen).
- Cumpleaños del año completo (miembros y familiares) agrupados por mes.
- Envío de felicitaciones como mensaje directo en el chat interno.

### Biblioteca
- Planchas por grado y libros con calificaciones.

### Marketplace / Negocios
Estilo "Facebook Marketplace" para el taller:
- Publicación de **servicios, productos y empleos** con categorías.
- Múltiples imágenes por anuncio, galería con carrusel.
- Filtros: tipo, rango de precio, ubicación, estado, orden (recientes, precio, populares).
- Estados: `disponible / reservado / vendido / pausado`.
- **Favoritos**, contador de vistas, reportes, URLs amigables (slug), mapa Leaflet cuando hay coordenadas.
- Mensajería 1-a-1 entre comprador y vendedor con `turbo_stream_from` (tiempo real).

### Chat interno
- Canales `logia`, `tenant` y mensajes directos (`dm`).
- Broadcast vía ActionCable + Turbo Streams.

### Dashboard
- Indicadores de cartera, mora, recaudos del mes y el año.
- Resumen por logia para admins del tenant raíz.

---

## Stack técnico

| Área | Tecnología |
|---|---|
| Backend | Rails 8, Ruby 3.4, Puma, Propshaft |
| DB | PostgreSQL, Solid Cache / Queue / Cable |
| Frontend | Turbo 8, Stimulus, Bootstrap 5, SCSS |
| Archivos | Active Storage (imágenes, PDFs, soportes) |
| Auth | Devise 4.9 |
| Autorización | Pundit + cargos (check por nombre vigente) |
| Paginación | Kaminari |
| OCR / PDF | `rtesseract`, `pdf-reader`, `wicked_pdf` |
| Maps | Leaflet + OpenStreetMap |
| Deploy | Kamal, Dockerfile, Thruster |

---

## Arquitectura multi-tenant

El tenant se resuelve en este orden (`ApplicationController#current_logia`):

1. **Preview** de super-admin (`session[:preview_logia_id]`).
2. **Subdominio** del request (`freemasons.localhost` → `Logia.find_by(slug: "freemasons")`).
3. **Logia del usuario** autenticado.
4. Primera logia como fallback.

Jerarquía: una logia **raíz** (tenant) puede tener logias **hijas**. El scope `ids_tenant(logia)` expande al raíz + todas sus hijas + hermanas, para mostrar contenido del tenant completo (cumpleaños, negocios, biblioteca, hospitalia).

---

## Roles y cargos

### Roles (tabla `roles`)
| Código | Descripción |
|---|---|
| `super_admin` | Acceso total, multi-tenant, preview de cualquier logia. |
| `admin_logia` | Administra su logia (y las hijas si es del tenant raíz). |
| `miembro` | Acceso limitado a su información, negocios, chat y módulos para los que tenga un **cargo**. |

### Cargos (`Cargo` + `MiembroCargo` vigente)
El método `User#tiene_cargo?("Tesorero")` controla el acceso modular. `admin_logia` y `super_admin` pasan siempre.

| Cargo | Módulo restringido |
|---|---|
| `Tesorero` | `/cobros`, `/periodos`, `/conceptos_cobro`, `/cortes_conciliacion` |
| `Hospitalario` | `/hospitalia/*` |

Otros cargos predefinidos (Venerable Maestro, Orador, Secretario, etc.) se usan solo para directorio.

---

## Requisitos

- **Ruby** 3.4.5 (ver `.ruby-version`)
- **Node** (ver `.node-version`) y **Yarn** 1.x
- **PostgreSQL** 14+
- **libvips** / **ImageMagick** (procesamiento de imágenes de Active Storage)
- **Tesseract OCR** (opcional, para lectura de soportes de pago)

---

## Puesta en marcha

```bash
git clone https://github.com/hectronix2005/COMUNIA.git
cd COMUNIA

bundle install
yarn install

# Copia y edita credenciales si necesitas (nunca commitear .env)
bin/rails db:create db:migrate db:seed

# Servidor de desarrollo (Rails + watcher CSS)
bin/dev
```

Accede a `http://localhost:3000` o, para un tenant específico vía subdominio:

```
http://freemasons.localhost:3000
http://los-magios.localhost:3000
```

### Credenciales demo

En la pantalla de login hay credenciales demo listables (botones "clic para usar"). Por defecto el super-admin es `sadmin` / password administrada vía seeds. Los miembros de prueba usan `password123`.

### Seed de datos masivos

```bash
# Datos de prueba en Marketplace (23 anuncios con imágenes)
bin/rails runner scripts/seed_marketplace.rb

# Importar cumpleaños y familiares desde un CSV (Google Sheet)
bin/rails runner scripts/import_cumpleanos.rb
```

---

## Estructura del proyecto

```
app/
├── controllers/       # Negocios, Hospitalia, Cobros, Biblioteca, etc.
├── models/            # User, Miembro, Cargo, NegocioAnuncio, ...
├── views/
│   ├── negocios/       # Marketplace (index, show, card, form, favoritos)
│   ├── hospitalia/     # Recaudos, gastos, cumpleaños
│   ├── biblioteca_*/   # Planchas, libros
│   ├── chat/           # Chat interno
│   └── layouts/        # application.html.erb
├── helpers/
└── policies/          # Pundit

config/
├── routes.rb          # Todas las rutas (marketplace con slug, hospitalia, tesorería)
├── locales/           # es.yml con datetime + devise
└── initializers/
    └── inflections.rb # Inflexiones en español (logias, negocio_conversaciones, ...)

db/migrate/            # ~40 migraciones
scripts/               # Seeds y utilitarios
```

---

## Scripts útiles

| Script | Uso |
|---|---|
| `scripts/seed_marketplace.rb` | Crea 23 anuncios de demostración en el tenant `freemasons` con imágenes de Picsum. |
| `scripts/import_cumpleanos.rb` | Importa familiares desde un CSV (Google Sheet); matching fuzzy + registro de alias automático. |

---

## Despliegue

Preparado para **Kamal** (ver `.kamal/`) con `Dockerfile` y `Thruster` como edge layer.

```bash
kamal setup        # primera vez
kamal deploy       # despliegues subsecuentes
```

Variables de entorno críticas (no commitear):

```
RAILS_MASTER_KEY=...
DATABASE_URL=postgres://...
SMTP_*            # para notificaciones por correo
```

---

## Licencia

Propietario. Uso restringido a las logias autorizadas por COMUNIA.
