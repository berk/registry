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
require 'acts_as_versioned'

module Registry
  class Entry < ActiveRecord::Base

    acts_as_versioned :table_name => 'registry_entry_versions'

    set_table_name :registry_entries

    belongs_to :parent,     :class_name => 'Entry', :foreign_key => 'parent_id'
    has_many   :children,   :class_name => 'Entry', :foreign_key => 'parent_id', :order => 'key asc', :dependent => :destroy

    before_save :ensure_env
    before_save :normalize_key
    before_save :normalize_value

    # after_update caused intermittent cache clearing
    after_save  :clear_cache

    before_destroy :log_deletion

    ROOT_ACCESS_KEY      = 'root'
    ROOT_LABEL           = 'Configuration Schema'
    DEFAULT_YML_LOCATION = "#{Rails.root}/config/registry.yml"

    # Returns the list of environments defined in the registry
    #
    # call-seq:
    #   Registry::Entry.environments #=> ['development', 'test', 'qa', 'stage', 'production']
    def self.environments
      connection.select_values("SELECT DISTINCT env FROM #{table_name} WHERE parent_id IS NULL")
    end

    # Export the registry to a YAML file and return the hash.
    #
    # ==== Parameters
    #
    # * +file_path+ - Optional path to file.  If nil no file is written.
    #
    # call-seq:
    #   Registry::Entry.export! #=> {'development' => {...}, 'test' => {...}, ...}
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

    # Import registry from a YAML file.
    #
    # ==== Parameters
    #
    # * +file_path+ - Path to yml file.
    # * +opts+      - Optional, merge options (see documentation for <tt>merge</tt> method)
    #
    # ==== File Format
    #
    # yml File should be in the following format:
    #
    # development:
    #   api:
    #     enabled:        true
    #     request_limit:  1
    #
    # test:
    #   api:
    #     enabled:        true
    #     request_limit:  1
    #
    # production:
    #   api:
    #     enabled:        false
    #     request_limit:  1
    #
    #
    # call-seq
    #   Registry::Entry.import!('/path/to/my.yml')
    def self.import!(file_path = DEFAULT_YML_LOCATION, opts={})
      hash = YAML.load_file(file_path)
      default_entries = hash.delete(Registry::DEFAULTS_KEY) || {}
      hash.each do |env, entries|
        root(env).merge(default_entries.deep_merge(entries), opts)
      end
    end

    # Return the root entry for an environment.
    #
    # ==== Parameters
    #
    # * +env+ - Optional environment (defaults to Rails.env)
    #
    # call-seq:
    #   Registry::Entry.root
    def self.root(env=Rails.env)
      first(:conditions => ['parent_id IS NULL AND env = ?', env]) || Folder.create(:env => env, :key => ROOT_ACCESS_KEY, :label => ROOT_LABEL)
    end

    # Return an array ancestor entries.
    def ancestors
      node, nodes = self, []
      nodes << node = node.parent while node.parent
      nodes
    end

    # Return the child entry for a path.
    #
    # ==== Parameters
    #
    # * +path+ - path to child
    #
    # call-seq:
    #   Registry::Entry.root.child('/api/enabled')
    def child(path)
      path.split('/').reject{|ii| ii.blank?}.inject(self) do |parent, key|
        parent.children.find_by_key(key).tap {|ii| raise ArgumentError.new("#{parent.key} has no child named #{key}") if ii.nil?}
      end
    end

    # Return true if the entry is a folder (contains children).
    def folder?
      false
    end

    # Create a property
    #
    # ==== Parameters
    #
    # * +hash+ - Hash of field names and values 
    #
    # call-seq:
    #   Registry.entry.root.child('/api').create_property(:key => 'enabled', :value => true)
    def create_property(hash)
      Entry.create!(hash.merge(:parent => self))
    end

    # Return a list of child properties.
    #
    # call-seq:
    #   Registry::Entry.root.child('/api').properties
    def properties
      children.select {|child| not child.folder?}
    end

    # Create and return a folder.
    #
    # ==== Parameters
    #
    # * +hash+ - Hash of field names and values 
    #
    # call-seq:
    #   Registry::Entry.root.create_folder(:key => 'api' :label => 'API', :description => 'API Settings')
    def create_folder(hash)
      Folder.create!(hash.merge(:parent => self))
    end

    # Return a list of child folders.
    #
    # call-seq:
    #   Registry::Entry.root.child('/api').folders
    def folders
      children.select {|child| child.folder?}
    end

    # :nodoc:
    def to_folder_hash
      {
        'id'    => id.to_s,
        'key'   => Transcoder.to_db(key),
        'label' => label.to_s,
        'text'  => (label.blank? ? key : label),
        'cls'   => 'folder',
      }
    end

    # :nodoc:
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

    # :nodoc:
    def to_form_property_hash
      {
        'key'          => key.to_s,
        'value'        => value.to_s,
        'label'        => label.to_s,
        'description'  => description.to_s,
      }
    end

    # Return a hash containing registry key/value pairs.
    #
    # ==== Parameters
    #
    # * +hash+ - Optional, hash to update.
    #
    # call-seq:
    #   Registry::Entry.root.export #=> {'api' => {'enabled' => true}, '_last_updated_at' => ...}
    def export(hash={}, entries=nil)

      if entries.nil?
        entries = Entry.all(:conditions => ['env = ? and id != ?', env, id])
        hash['_last_updated_at'] = entries.inject(Time.at(0)) {|old_max, entry| [old_max, entry.updated_at].max}
      end

      properties, entries = entries.partition {|entry| entry.parent_id == id && !entry.folder?}
      properties.each do |p|
        hash[Transcoder.from_db(p.key)] = Transcoder.from_db(p.value)
      end

      folders, entries = entries.partition {|entry| entry.parent_id == id && entry.folder?}
      folders.each do |f|
        hash[f.key] ||= {}
        f.export(hash[f.key], entries)
      end

      hash
    end

    # Merge a hash into the current sub-tree.
    #
    # This method will not overwrite key/value pairs already present in leaf nodes.
    #
    # ==== Parameters
    #
    # * +hash+ - hash to merge
    # * +opts+ - Optional merge options
    #
    # ==== Options
    #
    # * <tt>skip_already_deleted</tt> - If true, don't add folders/properties that were previously deleted. (default false)
    # * <tt>delete</tt> - If true, delete entries that are not in +hash+. (default false)
    #
    # call-seq:
    #   Registry::Entry.root.merge({'api' => {'enabled' => true}})
    #   Registry::Entry.root.merge({'api' => {'enabled' => true}}, :skip_already_deleted => true)
    def merge(hash, opts={})
      hash.each do |key, value|
        key = Transcoder.to_db(key)
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

      if opts[:delete]
        keys = hash.keys.map {|ii| Transcoder.to_db(ii)}
        children.each do |child|
          child.delete unless keys.include?(child.key)
        end
      end
    end

  private

    # Used by UI to get the String containing the ruby code used to access this entry.
    def access_code
      parts = [ 'Registry' ]
      parts << (ancestors.collect{|a| a.key}.reverse - [ROOT_ACCESS_KEY])
      parts.flatten!.compact!
      parts << (([TrueClass, FalseClass].include?(Transcoder.from_db(value).class)) ? "#{key}?" : key)
      parts.join('.')
    end

    def ensure_env
      self.env ||= parent.env
    end

    def normalize_key
      self.key = Transcoder.to_db(key) unless key.is_a?(String)
    end

    def normalize_value
      self.value = Transcoder.to_db(value) unless value.is_a?(String)
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
