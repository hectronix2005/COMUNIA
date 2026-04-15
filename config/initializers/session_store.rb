# Forzamos path: "/" en la cookie de sesión para que NO herede el
# SCRIPT_NAME que el middleware TenantPathPrefix establece (ej.
# /t/freemasons). Sin esto, la sesión se ata al sub-path del tenant y al
# cerrar sesión desde otro contexto la cookie no se borra correctamente.
Rails.application.config.session_store :cookie_store,
                                       key: "_gran_logia_de_colombia_session",
                                       path: "/"
