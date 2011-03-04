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
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#  version     :integer
#  notes       :text
#
# Indexes
#
#  index_registry_entries_on_parent_id_and_key      (parent_id, key)
#

require 'registry'
require File.expand_path(File.dirname(__FILE__) + '/../../../vendor/gems/metaskills-acts_as_versioned-0.6.3/lib/acts_as_versioned')

module Registry
  class Entry < ActiveRecord::Base

    acts_as_versioned :table_name => 'registry_entry_versions'

    set_table_name :registry_entries

    belongs_to :parent,     :class_name => 'Entry', :foreign_key => 'parent_id'
    has_many   :children,   :class_name => 'Entry', :foreign_key => 'parent_id', :order => 'key asc', :dependent => :destroy

    before_save :ensure_env
    before_save :normalize_key
    before_save :normalize_value
    after_update :clear_cache

    before_destroy :log_deletion

    ROOT_ACCESS_KEY      = 'root'
    ROOT_LABEL           = 'Configuration Schema'
    DEFAULT_YML_LOCATION = "#{Rails.root}/config/registry.yml"

    def self.environments
      connection.select_values("SELECT DISTINCT env FROM #{table_name} WHERE parent_id IS NULL")
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

    def self.import!(file_path = DEFAULT_YML_LOCATION, opts={})
      YAML.load_file( file_path ).each do |env, entries|
        root(env).merge(entries, opts)
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
        'key'   => encode(key),
        'label' => label.to_s,
        'text'  => (label.blank? ? key : label),
        'cls'   => 'folder',
      }
    end

    def to_grid_property_hash
      {
        'id'           => id.to_s,
        'key'          => key,
        'value'        => value,
        'label'        => (label.blank? ? key : label),
        'description'  => description.to_s,
        'access_code'  => access_code,
        'notes'        => notes.to_s,
      }
    end

    def to_form_property_hash
      {
        'key'          => key.to_s,
        'value'        => value.to_s,
        'label'        => label.to_s,
        'description'  => description.to_s,
      }
    end

    def export(hash={}, entries=nil)
      entries ||= Entry.all(:conditions => ['env = ? and id != ?', env, id])

      properties, entries = entries.partition {|entry| entry.parent_id == id && !entry.folder?}
      properties.each do |p|
        hash[decode(p.key)] = decode(p.value)
      end

      folders, entries = entries.partition {|entry| entry.parent_id == id && entry.folder?}
      folders.each do |f|
        hash[f.key] = {}
        f.export(hash[f.key], entries)
      end

      hash
    end

    def merge(hash, opts={})
      hash.each do |key, value|
        key = encode(key)
        reg = Entry.first(:conditions => ['parent_id = ? AND key = ?', self, key])
        if value.is_a?(Hash)
          reg = create_folder(:key => key) if reg.nil? && should_create?(key, opts)
          reg.merge(value, opts) unless reg.nil?
        elsif reg.nil? && should_create?(key, opts)
          create_property(:key => key, :value => value)
        else
          # don't overwrite
        end
      end
    end

  private

    def encode(value)
      case value
        when Array                  then "[#{value.map {|ii| encode(ii)}.join(',')}]"
        when Date,Time              then value.strftime("%Y-%m-%d %H:%M:%S %Z")
        when Symbol                 then ":#{value}"
        when TrueClass,FalseClass   then value ? 'true' : 'false'
        else                             value.to_s
      end
    end

    def decode(value)
      return value unless value.is_a?(String)

      return value[1 .. -2].split(',').map { |ii| decode(ii) }  if value[0,1] == '[' and value[-1,1] == ']' # array
      return 'true' == value                                    if value =~ /^(true|false)$/i               # boolean
      return eval(value)                                        if value =~ /\.\.|^:/                       # symbol or range
      return Time.parse(value)                                  if value =~ /\d+-\d+-\d+ \d+:\d+:\d+/       # date/time
      return value.to_i                                         if value =~ /^[-+]?[\d_,]+$/                # int
      return value.to_f                                         if value =~ /^[-+]?[\d_,.]+$/               # float

      value                                                                                                 # string
    end

    def access_code
      parts = [ 'Registry' ]
      parts << (ancestors.collect{|a| a.key}.reverse - [ROOT_ACCESS_KEY])
      parts.flatten!.compact!
      parts << (([TrueClass, FalseClass].include?(decode(value).class)) ? "#{key}?" : key)
      parts.join('.')
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

    def should_create?(key, opts)
      !opts[:skip_already_deleted] || no_prior_deleted_version?(key)
    end

    def no_prior_deleted_version?(key)
      Registry::Entry::Version.first(:conditions => {:parent_id => id, :key => key}).nil?
    end

    def clear_cache
      Registry.clear_cache(env)
    end

    def log_deletion
      update_attributes(:notes => '*** entry deleted ***')
    end

  end # class Entry
end # module Registry
