class AddDatosOcrToPagos < ActiveRecord::Migration[8.0]
  def change
    add_column :pagos, :datos_ocr, :jsonb
  end
end
