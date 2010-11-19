# == Schema Information
#
# Table name: registry_entries
#
#  id          :integer         not null, primary key
#  env         :string(255)
#  parent_id   :integer
#  key         :string(255)
#  type        :string(255)
#  value       :string(255)
#  label       :string(255)
#  description :string(255)
#  user_type   :string(255)
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_registry_entries_on_user_type_and_user_id  (user_type,user_id)
#  index_registry_entries_on_parent_id              (parent_id)
#  index_registry_entries_on_env_and_key            (env,key)
#

require 'lib/registry'

module Registry
  class Entry < ActiveRecord::Base

    set_table_name :registry_entries

    belongs_to :parent,     :class_name => 'Entry', :foreign_key => 'parent_id'
    has_many   :children,   :class_name => 'Entry', :foreign_key => 'parent_id', :order => 'key asc', :dependent => :destroy

    before_save :ensure_env
    before_save :normalize_key
    before_save :normalize_value

    ROOT_ACCESS_KEY      = 'root'
    ROOT_LABEL           = 'Configuration Schema'
    DEFAULT_YML_LOCATION = "#{Rails.root}/config/registry.yml"

    def self.environments
      connection.select_values("SELECT DISTINCT env FROM #{table_name}")
    end

    def self.export!(file_path = DEFAULT_YML_LOCATION)
      yaml_data = {}

      environments.each do |env|
        yaml_data[env] = {}
        root(env).export(yaml_data[env])
      end

      if file_path
        File.open(file_path, 'w' ) do |out|
           YAML.dump( yaml_data, out )
        end
      end

      yaml_data
    end

    def self.import!(file_path = DEFAULT_YML_LOCATION)
      YAML.load_file( file_path ).each do |env, entries|
        root(env).merge(entries)
      end
    end

    def self.root(env = Rails.env)
      first(:conditions => ['parent_id IS NULL AND env = ?', env]) || Folder.create(:env => env, :key => ROOT_ACCESS_KEY, :label => ROOT_LABEL)
    end

    def ancestors
      node, nodes = self, []
      nodes << node = node.parent while node.parent
      nodes
    end

    def folder?
      false
    end

    def create_property(hash)
      Entry.create!(hash.merge(:parent => self))
    end

    def properties
      children.select {|child| not child.folder?}
    end

    def create_folder(hash)
      Folder.create!(hash.merge(:parent => self))
    end

    def folders
      children.select {|child| child.folder?}
    end

    def to_folder_hash
      {
        'id'    => id.to_s,
        'key'   => key.to_s,
        'label' => label.to_s,
        'text'  => (label.blank? ? key : label),
        'cls'   => 'folder'
      }
    end

    def to_grid_property_hash
      {
        'id'           => id.to_s,
        'label'        => (label.blank? ? key : label),
        'value'        => value.to_s,
        'key'          => key.to_s,
        'description'  => description.to_s
      }
    end

    def to_form_property_hash
      hash = {
        'label'               => label.to_s,
        'key'                 => key.to_s,
        'description'         => description.to_s,
      }

      unless id.blank?
        Entry.find(:all, :conditions => ['key = ?', key]).each do |reg|
          hash["#{reg.env}_value"] = reg.value
        end
      else
        Entry.environments.each do |env|
          hash["#{env}_value"] = ''
        end
      end

      hash
    end

    def regenerate_properties_keys!
      properties.each do |p|
        p.save!
      end

      folders.each do |f|
        f.regenerate_properties_keys!
      end
    end

    def short_key
ActiveSupport::Deprecation.warn('avoid short_key', caller)
      return '' if key.blank?
      @short_key ||= key.split(Registry.configuration.key_separator).last
    end

    def export(hash={})
      properties.each do |p|
        hash[decode(p.key)] = decode(p.value)
      end

      folders.each do |f|
        next if f.children.size == 0
        hash[f.key] = {}
        f.export(hash[f.key])
      end

      hash
    end

    def merge(hash)
      hash.each do |key, value|
        key = encode(key)
        reg = Entry.first(:conditions => ['parent_id = ? AND key = ?', self, key])
        if value.is_a?(Hash)
          reg = create_folder(:key => key) if reg.nil?
          reg.merge(value)
        elsif reg.nil?
          create_property(:key => key, :value => value)
        end
      end
    end

#    def self.delete_property(key)
#      # delete all values for all environments for a given key
#      destroy_all(:key => key)
#    end

  private

    def encode(value)
      case value
        when TrueClass,FalseClass   then value ? 'true' : 'false'
        when Symbol                 then ":#{value}"
        when Date,Time              then value.strftime("%Y-%m-%d %H:%M:%S %Z")
        else                             value.to_s
      end
    end

    def decode(value)
      return value unless value.is_a?(String)

      return 'true' == value              if value =~ /^(true|false)$/i
      return eval(value)                  if value =~ /\.\.|^:/
      return Time.parse(value)            if value =~ /\d+-\d+-\d+ \d+:\d+:\d+/
      return value.to_i                   if value =~ /^[-+]?[\d_,]+$/
      return value.to_f                   if value =~ /^[-+]?[\d_,.]+$/

      value
    end


    def generate_full_key(partial_key=key)
ActiveSupport::Deprecation.warn('avoid generate_full_key', caller)
      parts = []
      parts << (ancestors.collect{|a| a.key}.reverse - [ROOT_ACCESS_KEY])
      parts.flatten!.compact!
      parts << partial_key.split(Registry.configuration.key_separator).last
      parts.join(Registry.configuration.key_separator)
    end

    def ensure_env
      self.env ||= parent.env
    end

    def normalize_key
      self.key = encode(key)
    end

    def normalize_value
      self.value = encode(value)
    end

  end # class Entry
end # module Registry
