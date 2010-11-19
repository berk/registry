puts 'Initializing registry...'

base = File.expand_path(File.dirname(__FILE__) + '/..')

Dir["#{base}/config/initializers/*.rb"].each do |file|
  require file
end
