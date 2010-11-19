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
    sh "rcov --rails -t --sort coverage -o public/coverage -x '/usr/local/rvm/gems/ree-1.8.7-2010.02/gems' #{files}"
  end

  desc "Sync extra files from will_filter plugin."
  task :sync do
    system "rsync -ruv vendor/plugins/registry/db/migrate db"
    system "rsync -ruv vendor/plugins/registry/public ."
    system "rsync -ruv vendor/plugins/registry/config ."
  end

end
