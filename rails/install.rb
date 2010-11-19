puts 'Running install script...'

# sync/run migrations
system "rsync -ruv #{Rails.root}/vendor/plugins/registry/db/migrate #{Rails.root}/db"
system 'rake db:migrate'

# sync assets
system "rsync -ruv #{Rails.root}/vendor/plugins/registry/public #{Rails.root}"
