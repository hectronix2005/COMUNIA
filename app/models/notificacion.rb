class Notificacion < ApplicationRecord
  belongs_to :user
  belongs_to :logia, optional: true

  validates :tipo,   presence: true
  validates :titulo, presence: true

  scope :no_leidas, -> { where(leida: false) }
  scope :recientes, -> { order(created_at: :desc).limit(30) }

  def marcar_leida!
    update!(leida: true, leida_at: Time.current)
  end
end
