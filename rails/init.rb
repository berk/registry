puts 'Initializing registry...'

Dir["#{Rails.root}/vendor/plugins/registry/config/initializers/*.rb"].each do |file|
  require file
end
