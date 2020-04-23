namespace :registry do

  desc 'Annotate models'
  task :annotate do
    sh "annotate -p before -i -e tests"
  end

  desc 'Generate coverage report'
  task :coverage do
    ENV['COVERAGE'] = '1'
    system('rake test')
  end

  desc "Set a registry value (eg 'api.enabled'=true)"
  task :set => [:environment] do
    ARGV.shift
    ARGV.each do |key_value|
      key, value = key_value.split('=')
      key.gsub!('.','/')
      puts "Setting #{key} to #{value}"
      Registry::Entry.root.child(key).update_attributes(:value => value)
    end
  end

end
