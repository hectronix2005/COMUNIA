namespace :red do
  desc "Carga datos ficticios de demostración de la Red COMUNIA (nunca en producción)"
  task demo: :environment do
    load Rails.root.join("db/seeds/red_demo.rb")
  end
end
