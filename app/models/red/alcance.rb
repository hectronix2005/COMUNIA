module Red
  # Una comunidad concreta elegida por la persona para su perfil o una publicación.
  class Alcance < ApplicationRecord
    belongs_to :objeto, polymorphic: true
    belongs_to :comunidad, class_name: "Red::Comunidad"
  end
end
