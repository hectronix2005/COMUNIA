# Reporte de algo publicado en una sombrilla: una persona, una vez; cuenta la comunidad desde la que reporta.
class SombrillaReporte < ApplicationRecord
  self.table_name = "sombrilla_reportes"
  belongs_to :reportable, polymorphic: true
  belongs_to :user
  belongs_to :comunidad, class_name: "Logia"
end
