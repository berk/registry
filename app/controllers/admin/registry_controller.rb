# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class Admin::RegistryController < AdminController
  
  def index
    
  end
  
  def viewport
    @root = Registry.root
    render :layout => false
  end
  
  def delete_folder
    node = Registry.find_by_id(params[:node]) unless params[:node].index("xnode")
    node.destroy if node
    render :text => "done"
  end
  
  def folders
    folders = []
    node = Registry.root if params[:node] == Registry::ROOT_KEY
    node = Registry.find_by_id(params[:node]) unless node
    node.folders.each do |child|
      folders << child.to_folder_hash
    end
    render :text => folders.to_json
  end
  
  def folder
    results = {:success => true, :total => 1, :folders => []}
    if request.post?
      if params[:folder_id].blank? or params[:folder_id].index('xnode')
        parent = Registry.find_by_id(params[:parent_id])
        parent = Registry.root unless parent
        fld = Registry.create(params[:folder].merge(:folder => true, :parent => parent))
      else
        fld = Registry.find(params[:folder_id])
        fld.update_attributes(params[:folder].merge(:folder => true))
        fld.regenerate_properties_keys!
      end
    else
      fld = Registry.find_by_id(params[:folder_id]) unless params[:folder_id].blank?
      fld = Registry.new(:label => "New Folder") unless fld
    end
 
    results[:folders] << fld.to_folder_hash
    render :text => results.to_json
  end  
  
  def property
    results = {:success => true, :total => 1, :properties => []}
    
    if request.post?
      if params[:prop_id].blank?
        parent = Registry.find_by_id(params[:parent_id])
        parent = Registry.root unless parent
        prop = Registry.create(params[:property].merge(:parent => parent))
      else
        prop = Registry.find(params[:prop_id])
        prop.update_attributes(params[:property])
      end
      prop.generate_key!
    else
      prop = Registry.find_by_id(params[:prop_id]) unless params[:prop_id].blank?
      prop = Registry.new unless prop
    end
 
    results[:properties] << prop.to_property_hash(false)
    render :text => results.to_json
  end
  
  def properties
    results = {:success => true, :total => 0, :properties => []}
  
    if request.get?
      node = Registry.find_by_id(params[:node]) unless (params[:node] and params[:node] == 'root')
      node = Registry.root unless node
      node.properties.each do |item|
        results[:properties] << item.to_property_hash
      end
      results[:total] = node.children.size
      
    elsif request.put?
      item = Registry.find_by_id(params[:properties][:id])
      item.update_attributes("#{Rails.env}_value" => params[:properties][:value])
      results[:properties] << item.to_property_hash
      results[:total] = 1
      
    elsif request.delete?
      node = Registry.find_by_id(params[:properties])
      node.destroy if node
    end
    
    render :text => results.to_json
  end
  
  def export
    yaml_data = Registry.export
    File.open("config/registry.yml", 'w' ) do |out|
       YAML.dump( yaml_data, out )
    end
    send_file("config/registry.yml", :type=>"text/yml", :filename => "registry.yml")    
  end

  def import
    yaml_data = YAML.load_file( "config/registry.yml" )
    Registry.import(yaml_data)
    redirect_to :action => :viewport
  end
  
  def reset_defaults
    Registry.reset(Rails.env)
    redirect_to :action => :viewport
  end
  
private

  def selected_root_key
    return Registry.find_by_id(params[:key_id]) if params[:key_id]
    Registry.root
  end

  
end
