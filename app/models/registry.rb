class Registry < ActiveRecord::Base

  set_table_name :registry
  
  belongs_to :parent, :class_name => "Registry", :foreign_key => "parent_id"
  has_many :children, :class_name => "Registry", :foreign_key => "parent_id", :order => "access_key asc", :dependent => :destroy
  
  DEFAULT_ENVIRONMENTS = ["development", "test", "qa", "staging", "production"]
  
  ROOT_ACCESS_KEY = 'root'
  ROOT_LABEL = "Configuration Schema"
  DEFAULT_YML_LOCATION = "config/registry.yml"

  def self.environments
    return REGISTRY_ENVIRONMENTS if defined?(REGISTRY_ENVIRONMENTS)
    DEFAULT_ENVIRONMENTS
  end
  
  def self.curr_env
    Rails.env
  end
  
  def curr_env
    self.class.curr_env
  end

  def self.export!(file_path = DEFAULT_YML_LOCATION)
    yaml_data = {}
    Registry.environments.each do |env|
      yaml_data[env] = {}      
      Registry.root.export(yaml_data[env], env)
    end

    File.open(file_path, 'w' ) do |out|
       YAML.dump( yaml_data, out )
    end
    
    yaml_data
  end

  def self.import!(file_path = DEFAULT_YML_LOCATION)
    Registry.delete_all

    yaml_data = YAML.load_file( file_path )
    node = Registry.create(:access_key => ROOT_ACCESS_KEY, :label => ROOT_LABEL, :folder => true)
    Registry.environments.each do |env|
      next unless yaml_data[env]
      node.import(yaml_data[env], env)
    end
  end
  
  def self.value_for(key, default = nil)
    reg = Registry.find(:first, :conditions => ["access_key = ? and env = ?", key, curr_env])
    return default unless reg
    reg.value.to_s  
  end
  
  def self.populate_defaults
    Registry.delete_all
    root = Registry.create(:access_key => ROOT_ACCESS_KEY, :label => ROOT_LABEL, :folder => true)
    1.upto(5) do |i|
      folder = Registry.create(:access_key => "folder#{i}", :label => "Folder #{i}", :parent => root, :folder => true)
      folder.generate_full_access_key!
      1.upto(10) do |j|
        Registry.environments.each do |env|
          property = Registry.create(:access_key => "property#{j}", :env => env, :value => "#{env} value #{j}", :description => "Very important property", :parent => folder)
          property.generate_full_access_key!
        end
      end
    end
  end

  # tree functions
  def self.roots
    find(:all, :conditions => "parent_id IS NULL", :order => "label asc, access_key asc")
  end

  def self.root
    node = find(:first, :conditions => "parent_id IS NULL", :order => "label asc, access_key asc")
    node = Registry.create(:access_key => ROOT_ACCESS_KEY, :label => ROOT_LABEL, :folder => true) unless node
    node
  end
  
  def ancestors
    node, nodes = self, []
    nodes << node = node.parent while node.parent
    nodes
  end

  def root
    node = self
    node = node.parent while node.parent
    node
  end

  def siblings
    self_and_siblings - [self]
  end

  def self_and_siblings
    parent ? parent.children : self.class.roots
  end
  
  def folders
    children.select{|c| c.folder?}
  end

  def properties(rails_env = curr_env)
    children.select{|c| (!c.folder? and c.env == rails_env)}
  end

  def to_folder_hash
    {
      "id"          => id.to_s,
      "access_key"  => short_key.to_s,
      "label"       => label.to_s,
      "text"        => (label.blank? ? short_key : label),
      "cls"         => "folder"
    }
  end

  def to_grid_property_hash
    {
      "id"                  => id.to_s,
      "label"               => (label.blank? ? short_key : label),
      "value"               => value.to_s,
      "access_key"          => access_key.to_s,
      "description"         => description.to_s
    }    
  end

  def to_form_property_hash
    hash = {
      "label"               => label.to_s,
      "key"                 => short_key.to_s,
      "description"         => description.to_s,
    }
    
    unless id.blank?
      Registry.find(:all, :conditions => ["access_key = ?", access_key]).each do |reg|
        hash["#{reg.env}_value"] = reg.value
      end
    else
      Registry.environments.each do |env|
        hash["#{env}_value"] = ""
      end
    end
    
    hash
  end
  
  def regenerate_properties_access_keys!
    properties.each do |p|
      p.generate_full_access_key!
    end
    
    folders.each do |f|
      f.regenerate_properties_access_keys!
    end
  end
  
  def short_key
    return "" if access_key.blank?
    @short_key ||= access_key.split(".").last
  end

  def generate_full_access_key(partial_key)
    parts = []
    parts << (ancestors.collect{|a| a.short_key}.reverse - [ROOT_ACCESS_KEY])
    parts.flatten!.compact!
    parts << partial_key.split(".").last
    parts.join(".")
  end
  
  def generate_full_access_key!
    self.access_key = generate_full_access_key(access_key)
    save if save
  end
  
  def value_for(env)
    send("#{env}_value")
  rescue NameError  
    raise Exception.new("Unsupported environment: #{env}")
  end
  
  def export(hash, env)
    properties(env).each do |p|
      hash[p.short_key] = p.value.to_s
    end
    
    folders.each do |f|
      next if f.children.size == 0
      hash[f.short_key] = {}
      f.export(hash[f.short_key], env)
    end
  end
  
  def import(hash, env)
    hash.each do |key, value|
      full_access_key = generate_full_access_key(key)
      if value.is_a?(Hash)
        reg = Registry.find(:first, :conditions => ["access_key = ?", full_access_key])
        reg = Registry.create(:access_key => full_access_key, :folder => true, :parent => self) unless reg
        reg.generate_full_access_key!
        reg.import(value, env)
      else
        reg = Registry.create(:access_key => full_access_key, :parent => self, :env => env, :value => value.to_s)
        reg.generate_full_access_key!
      end
    end
  end
  
  def self.delete_property(key)
    # delete all values for all environments for a given key
    Registry.find(:all, :conditions => ["access_key=?", key]).each do |reg|
      reg.destroy
    end
  end
  
end
