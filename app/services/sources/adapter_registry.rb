module Sources
  class AdapterRegistry
    def self.resolve(listing_source)
      adapter_class_for(listing_source.adapter_key).new
    end

    def self.adapter_class_for(adapter_key)
      "Sources::#{adapter_key.camelize}Adapter".constantize
    end

    private_class_method :adapter_class_for
  end
end
