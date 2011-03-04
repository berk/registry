class Registry::RegistryController < ApplicationController
  unloadable

  def index
    # Render the UI in an iframe to prevent conflicts between ExtJS and the hosting app's javascript library.
  end

  def viewport
    @root = Registry::Entry.root
    render :layout => false
  end

  def delete_folder
    unless params[:node].index('xnode')
      node = Registry::Folder.find_by_id(params[:node])
      node.destroy if node
    end
    render :text => 'done'
  end

  def folders
    folders = []
    node = Registry::Entry.root if params[:node] == Registry::Entry::ROOT_ACCESS_KEY
    node = Registry::Entry.find_by_id(params[:node]) unless node
    node.folders.each do |child|
      folders << child.to_folder_hash
    end
    render :text => folders.to_json
  end

  def folder
    results = {:success => true, :total => 1, :folders => []}

    if request.post?
      if params[:folder_id].blank? or params[:folder_id].index('xnode')
        fld = Registry::Folder.create(params[:folder].merge(:parent => parent, :user_id => registry_user_id))
      else
        fld = Registry::Entry.find(params[:folder_id])
        fld.update_attributes(params[:folder].merge(:user_id => registry_user_id))
      end
    else
      fld = Registry::Entry.find_by_id(params[:folder_id]) unless params[:folder_id].blank?
      fld = Registry::Entry.new unless fld
    end

    results[:folders] << fld.to_folder_hash
    render :text => results.to_json
  end

  def property
    results = {:success => true, :total => 1, :properties => []}

    if request.post?
      if params[:prop_id].blank?
        prop = Registry::Entry.create(params[:property].merge(:parent => parent, :user_id => registry_user_id))
      else
        prop = Registry::Entry.find_by_id(params[:prop_id]) || Registry::Entry.new(:parent => parent)
        prop.update_attributes(:key          => params[:property][:key],
                               :label        => params[:property][:label],
                               :description  => params[:property][:description],
                               :value        => params[:property][:value],
                               :user_id      => registry_user_id
                              )
      end
    else
      prop = Registry::Entry.find_by_id(params[:prop_id]) unless params[:prop_id].blank?
      prop = Registry::Entry.new unless prop
    end

    results[:properties] << prop.to_form_property_hash if prop
    render :text => results.to_json
  end

  def properties
    results = {:success => true, :total => 0, :properties => []}

    if request.get?
      node = Registry::Entry.find_by_id(params[:node]) unless (params[:node] and params[:node] == 'root')
      node = Registry::Entry.root unless node
      node.properties.each do |item|
        results[:properties] << item.to_grid_property_hash
      end
      results[:total] = node.children.size

    elsif request.put?
      item = Registry::Entry.find_by_id(params[:properties][:id])
      item.update_attributes("value" => params[:properties][:value], :user_id => registry_user_id)
      results[:properties] << item.to_grid_property_hash
      results[:total] = 1

    elsif request.delete?
      if node = Registry::Entry.find_by_id(params[:properties]) 
        node.update_attributes(:user_id => registry_user_id)
        node.destroy
      end
    end

    render :text => results.to_json
  end

  def revisions
    results = {:success => true, :revisions => []}

    @revisions = Registry::Entry::Version.all(:conditions => ['entry_id = ? OR parent_id = ?', params[:id], params[:id]], :order => 'id DESC')
    @revisions.each do |revision|
      results[:revisions] << {
        'id'      => revision.id.to_s,
        'label'   => revision.label.to_s,
        'value'   => revision.value.to_s,
        'user'    => registry_user_name(revision.user_id),
        'updated' => revision.updated_at.in_time_zone.to_s,
        'notes'   => revision.notes.to_s,
      }
    end

    render :text => results.to_json
  end

  def export
    Registry::Entry.export!('/tmp/registry.yml')
    send_file('/tmp/registry.yml', :type=>'text/yml', :filename => 'registry.yml')
  end

  def import
    Registry::Entry.import!("#{Rails.root}/config/registry.yml")
    redirect_to :action => :viewport
  end

private

  def parent
    @parent ||= Registry::Entry.find_by_id(params[:parent_id]) || Registry::Entry.root
  end

  def registry_user_id
    -1
  end

  def registry_user_name(id)
    id.to_s
  end

end
