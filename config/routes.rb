ActionController::Routing::Routes.draw do |map|
  map.namespace('registry') do |registry|
    registry.root :controller => :registry
  end
end
