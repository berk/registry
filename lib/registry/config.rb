module Registry
  class Config

    def permission_check(*args, &blk)
      if block_given?
        Registry::RegistryController.send(:define_method, :permission_check, &blk)
        Registry::RegistryController.prepend_before_filter(:permission_check)
      else
        Registry::RegistryController.filter_chain.delete_if { |ii| :permission_check == ii.method }
      end
    end

  end
end # module Registry
