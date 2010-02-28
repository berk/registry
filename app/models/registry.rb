class Registry < ActiveRecord::Base

  set_table_name :registry
  
  belongs_to :parent, :class_name => "Registry", :foreign_key => "parent_id"
  has_many :children, :class_name => "Registry", :foreign_key => "parent_id", :order => "key asc", :dependent => :destroy
  
  ENVIRONMENTS = ["development", "staging", "test", "production", "qa"]
  ROOT_KEY = 'root'
  ROOT_LABEL = "Configuration Schema"

  def self.export
    hash = {}
    ENVIRONMENTS.each do |env|
      hash[env] = {}      
      Registry.root.export(hash[env], env)
    end
    hash
  end

  def self.import(hash)
    Registry.delete_all
    root = Registry.create(:key => ROOT_KEY, :value => ROOT_LABEL, :folder => true)
    ENVIRONMENTS.each do |env|
      next unless hash[env]
      root.import(hash[env], env)
    end
  end
  
  def self.reset(env)
    Registry.root.reset(env)
  end
  
  def self.value_for(key, default = nil)
    reg = Registry.find_by_key(key)
    return default unless reg
    reg.value  
  end
  
  def self.populate_defaults
    Registry.delete_all
    root = Registry.create(:key => ROOT_KEY, :value => ROOT_LABEL, :folder => true)
    1.upto(5) do |i|
      folder = Registry.create(:key => "folder#{i}", :value => "Folder #{i}", :parent => root, :folder => true)
      1.upto(10) do |j|
        property = Registry.create(:key => "property#{j}", :value => "Value #{j}", :description => "Very important property", :parent => folder, :folder => false)
        property.generate_key!
      end
    end
  end

  # tree functions
  def self.roots
    find(:all, :conditions => "parent_id IS NULL", :order => "key asc")
  end

  def self.root
    node = find(:first, :conditions => "parent_id IS NULL", :order => "key asc")
    node = Registry.create(:key => ROOT_KEY, :value => ROOT_LABEL, :folder => true) unless node
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

  def properties
    children.select{|c| !c.folder?}
  end

  def to_folder_hash
    {
      "id"    => id.to_s,
      "text"  => (value.blank? ? key : value),
      "cls"   => "folder"
    }
  end

  def to_property_hash
    {
      "id"                  => id.to_s,
      "key"                 => short_key,
      "full_key"            => key,
      "value"               => value,
      "description"         => description.to_s,
      "default_test"        => default_test,
      "default_qa"          => default_qa,
      "default_production"  => default_production,
      "default_staging"     => default_staging,
      "default_development" => default_development
    }    
  end
  
  def regenerate_properties_keys!
    properties.each do |p|
      p.generate_key!
    end
    
    folders.each do |f|
      f.regenerate_properties_keys!
    end
  end
  
  def short_key
    return "" unless key
    @short_key ||= key.split(".").last
  end

  def generate_key(source_key)
    keys = []
    keys << (ancestors.collect{|a| a.key}.reverse - [ROOT_KEY])
    keys.flatten!.compact!
    keys << source_key.split(".").last
    keys.join(".")
  end
  
  def generate_key!
    self.key = generate_key(key)
    save if save
  end
  
  def default_value_for(env)
    eval("default_#{env}")
  rescue NameError  
    raise Exception.new("Unsupported environment: #{env}")
  end
  
  def export(hash, env)
    properties.each do |p|
      hash[p.short_key] = p.default_value_for(env).to_s
    end
    
    folders.each do |f|
      next if f.children.size == 0
      hash[f.key] = {}
      f.export(hash[f.key], env)
    end
  end
  
  def import(hash, env)
    hash.each do |key, value|
      if value.is_a?(Hash)
        reg = Registry.find_by_parent_id_and_key(self.id, key)
        reg = Registry.create(:key => key, :value => key, :folder => true, :parent => self) unless reg
        reg.import(value, env)
      else
        full_key = generate_key(key)
        reg = Registry.find_by_parent_id_and_key(self.id, full_key)
        reg = Registry.create(:key => full_key, :parent => self) unless reg
        data = {"default_#{env}" => value.to_s}
        data.merge!({"value" => value.to_s}) if Rails.env == env
        reg.update_attributes(data)
      end
    end
  end

  def reset(env)
    properties.each do |p|
      p.value = p.default_value_for(env).to_s
      p.save
    end
    
    folders.each do |f|
      f.reset(env)
    end
  end
  
end
