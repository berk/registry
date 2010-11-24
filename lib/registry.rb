module Registry

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
    (@registry ||= RegistryWrapper.new(Entry.root.export)).send(method, *args)
  end

  # Reset the registry.
  #
  # This will force a reload next time it is accessed.
  #
  def self.reset
    @registry = nil
  end

  # Import registry values from yml file.
  #
  # File should be in the following format:
  #
  #---
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
  #---
  # call-seq:
  #   Registry.import("#{Rails.root}/config/defaults.yml")
  #
  def self.import(file)
    Entry.import!(file)
  end

private

  class RegistryWrapper

    def initialize(hash)
      @hash = hash
    end

    def method_missing(method, *args)
      method = method.to_s
      boolean_expected = ('?' == method[-1, 1])
      method = method[0 .. -2] if boolean_expected
      ret = @hash[method]
      ret = RegistryWrapper.new(ret) if ret.is_a?(Hash) and not boolean_expected
      boolean_expected ? !!ret : ret
    end

    def to_hash
      @hash
    end
  end

end # module Registry
