# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class Registry::RegistryController < ApplicationController
  
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
    node = Registry.root if params[:node] == Registry::ROOT_ACCESS_KEY
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
      end
      fld.generate_full_access_key!
    else
      fld = Registry.find_by_id(params[:folder_id]) unless params[:folder_id].blank?
      fld = Registry.new unless fld
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
        
        Registry.environments.each do |env|
          prop = Registry.create(:parent      => parent, 
                                 :access_key  => params[:property][:key], 
                                 :label       => params[:property][:label],
                                 :description => params[:property][:description],
                                 :env         => env,
                                 :value       => params[:property]["#{env}_value"])
          prop.generate_full_access_key!                                 
        end
      else
        prop = Registry.find(params[:prop_id])
        Registry.environments.each do |env|
          reg = Registry.find(:first, :conditions => ["access_key = ? and env = ?", prop.access_key, env])
          reg = Registry.create(:parent => prop.parent, :env => env) unless reg
          reg.update_attributes(:access_key   => params[:property][:key],
                                :label        => params[:property][:label],
                                :description  => params[:property][:description],
                                :value        => params[:property]["#{env}_value"])
          reg.generate_full_access_key!                     
        end
      end
    else
      prop = Registry.find_by_id(params[:prop_id]) unless params[:prop_id].blank?
      prop = Registry.new unless prop
    end
 
    results[:properties] << prop.to_form_property_hash if prop
    render :text => results.to_json
  end
  
  def properties
    results = {:success => true, :total => 0, :properties => []}
  
    if request.get?
      node = Registry.find_by_id(params[:node]) unless (params[:node] and params[:node] == 'root')
      node = Registry.root unless node
      node.properties.each do |item|
        results[:properties] << item.to_grid_property_hash
      end
      results[:total] = node.children.size
      
    elsif request.put?
      item = Registry.find_by_id(params[:properties][:id])
      item.update_attributes("value" => params[:properties][:value])
      results[:properties] << item.to_grid_property_hash
      results[:total] = 1
      
    elsif request.delete?
      node = Registry.find_by_id(params[:properties])
      Registry.delete_property(node.access_key) if node
    end
    
    render :text => results.to_json
  end
  
  def export
    Registry.export!("config/registry.yml")
    send_file("config/registry.yml", :type=>"text/yml", :filename => "registry.yml")    
  end

  def import
    Registry.import!("config/registry.yml")
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
