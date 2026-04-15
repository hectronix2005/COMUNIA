class RenameSoporteToSoportesInActiveStorage < ActiveRecord::Migration[8.0]
  def up
    ActiveStorage::Attachment
      .where(record_type: "Pago", name: "soporte")
      .update_all(name: "soportes")
  end

  def down
    ActiveStorage::Attachment
      .where(record_type: "Pago", name: "soportes")
      .update_all(name: "soporte")
  end
end
