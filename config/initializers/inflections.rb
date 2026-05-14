# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "logia", "logias"
  inflect.irregular "periodo_cobro", "periodo_cobros"
  inflect.irregular "cobro", "cobros"
  inflect.irregular "pago", "pagos"
  inflect.irregular "miembro", "miembros"
  inflect.irregular "concepto_cobro", "conceptos_cobro"
  inflect.irregular "corte_conciliacion", "corte_conciliaciones"
  inflect.irregular "negocio_conversacion", "negocio_conversaciones"
  inflect.irregular "negocio_mensaje", "negocio_mensajes"
  inflect.irregular "negocio_reporte", "negocio_reportes"
  inflect.irregular "negocio_favorito", "negocio_favoritos"
  inflect.irregular "notificacion", "notificaciones"
  inflect.irregular "push_subscription", "push_subscriptions"
end
