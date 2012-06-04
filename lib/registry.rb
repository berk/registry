module Registry

  DEFAULTS_KEY = 'defaults' unless defined?(DEFAULTS_KEY)

  # Configure the Registry Engine.
  #
  # call-seq:
  #   Registry.configure do |config|
  #
  #     # permission check used by Registry UI
  #     config.permission_check { current_user.admin? }
  #
  #     # layout used by Registry UI
  #     config.layout = 'admin'
  #   end
  #
  def self.configure
    yield configuration
  end

  # Returns the current registry configuration
  def self.configuration
    @configuration ||= Registry::Config.new
  end

  # Access registry values.
  #
  # call-seq:
  #
  #   Registry.api.enabled?       # => true
  #   Registry.api.request_limit? # => 1
  #
  def self.method_missing(method, *args)
    reset if should_reset?

    @registry ||= begin
      registry_hash = Rails.cache.fetch(cache_key) {Entry.root.export}
      RegistryWrapper.new(registry_hash)
    end

    @registry.send(method, *args)
  end

  # Reset the registry.
  #
  # This will force a reload next time it is accessed.
  #
  # ==== Parameters
  #
  # * +clear_cache+ - Optional, whether to clear the Rails cache after reset.
  #
  def self.reset(clear_cache=nil)
    return if prevent_reset?
    @registry = nil
    @last_reset_time = Time.now
    self.clear_cache if clear_cache
  end

  # When the registry was last reset.
  def self.last_reset_time
    @last_reset_time
  end

  # Import registry values from yml file.
  #
  # ==== Prameters
  #
  # * +file+ - Name of yml file.
  # * +opts+ - Additional options see examples for usage.
  #
  # ==== Options
  #
  # * <tt>:purge</tt> - if true, deletes all entries before import.
  # * <tt>:testing</tt> - if true, don't save registry values.
  #
  # ==== File Format
  #
  # yml File should be in the following format:
  #
  # defaults:
  #   api:
  #     enabled:        true
  #     request_limit:  100
  #
  # development:
  #   api:
  #     request_limit:  1
  #
  # test:
  #   api:
  #     request_limit:  1
  #
  # production:
  #   api:
  #     enabled:        false
  #
  # call-seq:
  #   Registry.import("#{Rails.root}/config/defaults.yml")
  #   Registry.import("#{Rails.root}/config/defaults.yml", :purge => true)
  #   Registry.import("#{Rails.root}/config/defaults.yml", :testing => true)
  #
  def self.import(file, opts={})
    if opts[:testing]
      hash = YAML.load_file(file)
      hash = (hash[DEFAULTS_KEY] || {}).deep_merge(hash[Rails.env.to_s])
      @registry = RegistryWrapper.new(hash)
      return
    end

    if opts[:purge]
      Entry.delete_all
      Entry::Version.delete_all
    end

    Entry.import!(file, opts)
  end

  # :nodoc:
  def self.prevent_reset?
    @prevent_reset
  end

  # Return changes made at the end of a path
  #
  # ==== Parameters
  #
  # * +path+ - path to child.
  # * +env+  - Optional, Rails environment.
  #
  # call-seq:
  #   Registry.versions('api/enabled')       #=> changes made to enabled flag.
  #   Registry.versions('api/enabled', 'qa') #=> changes made to enabled flag in QA environment.
  def self.versions(path, env=Rails.env)
    Entry.root(env).child(path).versions
  end

protected

  # :nodoc:
  def self.prevent_reset!
    @prevent_reset = true
  end

  # :nodoc:
  def self.allow_reset!
    @prevent_reset = nil
  end

  # :nodoc:
  def self.cache_key(env=Rails.env.to_s)
    "#{env}-registry"
  end

  # :nodoc:
  def self.clear_cache(env=Rails.env.to_s)
    Rails.cache.delete(cache_key(env))
  end

private

  def self.should_reset?
    false
  end

  class RegistryWrapper

    def initialize(hash, parent_path='')
      @parent_path = parent_path
      @hash = hash.dup
    end

    def method_missing(method, *args)
      super
    rescue NoMethodError
      raise unless exists?(method)
      add_methods_for(method)
      send(method, *args)
    end

    def to_hash
      @hash
    end

    def exists?(method)
      @hash.key?( method_key(method) )
    end

    def with(config_hash, &block)
      result = nil
      orig_config = {}

      @saved_prevent_reset = Registry.prevent_reset?
      begin
        config_hash.each do |kk,vv|
          orig_config[kk] = self.send(kk)
          self.send("#{kk}=", vv, false)
        end

        Registry.prevent_reset!
        result = block.call
      ensure
        Registry.allow_reset! unless @saved_prevent_reset
        orig_config.each { |kk,vv| self.send("#{kk}=", vv, false) }
      end

      result
    end

  private

    def method_key(method)
      method.to_s.sub(/[\?=]{0,1}$/, '')
    end

    def add_methods_for(method)
      method = method_key( method )

      self.class_eval %{

        def #{method}                                               # def foo
          ret = @hash['#{method}']                                  #   ret = @hash['foo']
          if ret.is_a?(Hash)                                        #   if ret.is_a?(Hash)
            path = @parent_path + '/#{method}'                      #     path = @parent_path + '/foo'
            ret = @hash['#{method}'] = self.class.new(ret, path)    #     ret = @hash['foo'] = self.class.new(ret, path)
          end                                                       #   end
          ret                                                       #   ret
        end                                                         # end

        def #{method}=(value, save=true)                            # def foo=(value, save=true)
          @hash['#{method}'] = value                                #   @hash['foo'] = value
          update('#{method}', value) if save                        #   update('foo', value) if save
        end                                                         # end

        def #{method}?                                              # def foo?
          !!@hash['#{method}']                                      #   !!@hash['foo']
        end                                                         # end

      }, __FILE__, __LINE__
    end

    def update(key, value)
      Entry.root.child(@parent_path + '/' + key).update_attributes(:value => value)
    end

  end

end # module Registry

require 'registry/transcoder'
