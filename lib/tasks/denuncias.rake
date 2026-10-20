namespace :denuncias do
  desc "Asegura los triggers de solo inserción de la cadena de custodia"
  task triggers: :environment do
    Denuncias::Esquema.triggers!
  end
end

%w[db:prepare db:schema:load db:test:prepare].each do |tarea|
  Rake::Task[tarea].enhance { Rake::Task["denuncias:triggers"].tap(&:reenable).invoke } if Rake::Task.task_defined?(tarea)
end
