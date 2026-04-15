class Pago < ApplicationRecord
  include AttachmentValidations

  belongs_to :cobro
  belongs_to :validado_por, class_name: "User", optional: true
  has_many_attached :soportes
  validates_attachment :soportes, types: :doc, max: 10.megabytes, multi: true

  validates :monto_pagado, presence: true, numericality: { greater_than: 0 }
  validates :fecha_pago, presence: true
  validates :metodo_pago, presence: true
  validate :al_menos_un_soporte, on: :create

  validate :soportes_formato_y_tamano, if: -> { soportes.attached? }

  after_commit :analizar_soporte_async, on: [:create, :update], if: :soportes_recien_adjuntado?

  scope :validados, -> { where.not(numero_rc: nil) }
  scope :pendientes_validacion, -> { where(numero_rc: nil) }
  scope :recientes, -> { order(created_at: :desc) }

  METODOS_PAGO = %w[transferencia consignacion efectivo nequi daviplata].freeze
  DESCUENTO_MINIMO_PERIODOS = 6
  DESCUENTO_PORCENTAJE = 10 # 10%

  # Calcula descuento por pago adelantado (6+ periodos = 10%)
  def self.calcular_descuento(cantidad_periodos, monto_total)
    if cantidad_periodos >= DESCUENTO_MINIMO_PERIODOS
      porcentaje = DESCUENTO_PORCENTAJE
      descuento = (monto_total * porcentaje / 100.0).round(0)
      { aplica: true, porcentaje: porcentaje, descuento: descuento, total_con_descuento: monto_total - descuento }
    else
      { aplica: false, porcentaje: 0, descuento: 0, total_con_descuento: monto_total }
    end
  end

  # Encuentra todos los cobros que comparten el mismo soporte (pago multiple)
  def cobros_grupo
    return Cobro.where(id: cobro_id) unless soportes.attached?
    blob_ids = soportes.map { |s| s.blob.id }
    pago_ids = ActiveStorage::Attachment.where(
      record_type: "Pago", name: "soportes", blob_id: blob_ids
    ).pluck(:record_id).uniq
    Cobro.where(id: Pago.where(id: pago_ids).select(:cobro_id))
         .includes(:periodo_cobro, :pago)
         .order("periodo_cobros.anio ASC, periodo_cobros.mes ASC")
  end

  def pago_multiple?
    soportes.attached? && cobros_grupo.count > 1
  end

  def validado?
    numero_rc.present?
  end

  def validar!(admin)
    transaction do
      update!(
        validado_por: admin,
        validado_at: Time.current
      )
      cobro.pagado!
    end

    "RC Pendiente"
  end

  def asignar_rc!
    return numero_rc if numero_rc.present?

    logia = cobro.miembro.logia
    rc = logia.siguiente_rc!
    update!(numero_rc: rc)
    rc
  end

  def rechazar!
    transaction do
      # Solo purgar cada blob si ningun otro pago lo comparte
      if soportes.attached?
        soportes.each do |soporte|
          blob = soporte.blob
          otros = ActiveStorage::Attachment.where(
            record_type: "Pago", name: "soportes", blob_id: blob.id
          ).where.not(record_id: id).count
          if otros > 0
            soporte.detach
          else
            soporte.purge
          end
        end
      end
      cobro.pendiente!
      destroy!
    end
  end

  private

  def soportes_recien_adjuntado?
    soportes.attached? && datos_ocr.blank?
  end

  def analizar_soporte_async
    AnalizarSoporteJob.perform_later(id)
  end

  def al_menos_un_soporte
    errors.add(:soportes, "debe adjuntar al menos un comprobante") unless soportes.attached?
  end

  def soportes_formato_y_tamano
    soportes.each do |soporte|
      unless soporte.content_type.in?(%w[image/jpeg image/png application/pdf])
        errors.add(:soportes, "debe ser JPG, PNG o PDF")
        break
      end

      if soporte.blob.byte_size > 5.megabytes
        errors.add(:soportes, "no debe superar 5MB por archivo")
        break
      end
    end
  end
end
