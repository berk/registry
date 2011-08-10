namespace :registry do

  desc 'Annotate models'
  task :annotate do
    sh "annotate -p before -i -e tests"
  end

  desc 'Generate coverage report'
  task :coverage => [:environment] do
    excludes = %w[boot.rb config vendor].join(',')
    output_dir = "#{Rails.root}/public/coverage"
    files = Dir['test/{unit,functional}/**/*_test.rb'].join(' ')
    rm_rf(output_dir)
    sh "rcov --rails -t --sort coverage -o public/coverage -x 'gems' #{files}"
  end

  desc 'Set a registry value (eg api.enabled=true)'
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
