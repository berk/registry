ActionController::Routing::Routes.draw do |map|
  map.namespace('registry') do |registry|
    registry.root :controller => 'registry'
    registry.connect ':action/:id', :controller => 'registry'
  end
end
