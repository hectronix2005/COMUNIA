# Helpers reusables para validar uploads de Active Storage:
# tipo MIME real (vía io.content_type) y tamaño máximo.
module AttachmentValidations
  extend ActiveSupport::Concern

  IMAGE_TYPES    = %w[image/png image/jpeg image/jpg image/webp image/gif image/svg+xml].freeze
  DOC_TYPES      = (IMAGE_TYPES + %w[application/pdf]).freeze
  DOC_TYPES_FULL = (DOC_TYPES + %w[
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/msword
    application/vnd.ms-excel
    text/plain
  ]).freeze

  MAX_IMAGE_BYTES = 8.megabytes
  MAX_DOC_BYTES   = 25.megabytes

  class_methods do
    # Valida una asociación has_one_attached / has_many_attached.
    #
    # validates_attachment :logo, types: :image
    # validates_attachment :soportes, types: :doc, max: 10.megabytes, multi: true
    def validates_attachment(name, types: :doc, max: nil, multi: false)
      allowed_types = case types
                      when :image then IMAGE_TYPES
                      when :doc   then DOC_TYPES
                      when :any   then DOC_TYPES_FULL
                      else Array(types)
                      end
      max_bytes = max || (types == :image ? MAX_IMAGE_BYTES : MAX_DOC_BYTES)

      validate do |record|
        attachments = multi ? record.public_send(name) : Array(record.public_send(name))
        attachments.each do |att|
          next unless att&.attached?
          blob = att.respond_to?(:blob) ? att.blob : att
          unless allowed_types.include?(blob.content_type)
            record.errors.add(name, "tipo de archivo no permitido (#{blob.content_type})")
          end
          if blob.byte_size > max_bytes
            mb = (max_bytes.to_f / 1.megabyte).round(1)
            record.errors.add(name, "supera el tamaño máximo de #{mb} MB")
          end
        end
      end
    end
  end
end
