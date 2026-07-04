require "test_helper"

class Sources::AdapterRegistryTest < ActiveSupport::TestCase
  test "resolves info_casas_api adapter from the adapter key" do
    source = ListingSource.new(name: "InfoCasas API", adapter_key: "info_casas_api")

    adapter = Sources::AdapterRegistry.resolve(source)

    assert_instance_of Sources::InfoCasasApiAdapter, adapter
  end
end
