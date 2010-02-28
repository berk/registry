namespace :registry do

  desc "Creates necessary folders."
  task :init do
    
  end
  
  desc "Sync extra files from will_filter plugin."
  task :sync do
    system "rsync -ruv vendor/plugins/registry/db/migrate db"
    system "rsync -ruv vendor/plugins/registry/config ."
  end
  
end