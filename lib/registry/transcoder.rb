require 'registry/transcoder/base'

Dir["#{File.dirname(__FILE__)}/transcoder/*.rb"].each do |file|
  next if file.to_s =~ /base.rb/
  require_or_load file
end
