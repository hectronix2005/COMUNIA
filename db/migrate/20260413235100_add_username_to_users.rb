class AddUsernameToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :username, :string

    # Generate unique usernames for all existing users
    taken = {}
    User.order(:id).each do |user|
      base = generate_base(user.nombre, user.apellido)
      candidate = base
      suffix = 2
      while taken.key?(candidate)
        candidate = "#{base}#{suffix}"
        suffix += 1
      end
      taken[candidate] = true
      user.update_column(:username, candidate)
    end

    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    remove_column :users, :username
  end

  private

  def generate_base(nombre, apellido)
    nombre_clean  = transliterate(nombre.to_s.strip)
    apellido_clean = transliterate(apellido.to_s.strip.split.first.to_s)
    first_letter  = nombre_clean[0].to_s
    "#{first_letter}#{apellido_clean}".downcase.gsub(/[^a-z0-9]/, "")
  end

  def transliterate(str)
    str.unicode_normalize(:nfd).encode("ASCII", invalid: :replace, undef: :replace, replace: "")
  rescue
    str.gsub(/[áàäâã]/i, "a")
       .gsub(/[éèëê]/i, "e")
       .gsub(/[íìïî]/i, "i")
       .gsub(/[óòöôõ]/i, "o")
       .gsub(/[úùüû]/i, "u")
       .gsub(/[ñ]/i, "n")
  end
end
