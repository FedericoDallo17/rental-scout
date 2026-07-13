require "test_helper"

class ListingSourceTest < ActiveSupport::TestCase
  test "uses a product-facing name for the InfoCasas adapter" do
    source = ListingSource.new(name: "InfoCasas API", adapter_key: "info_casas_api")

    assert_equal "InfoCasas", source.display_name
    assert_equal "info_casas_api", source.adapter_key
  end

  test "falls back to the persisted name for other adapters" do
    source = ListingSource.new(name: "Remax", adapter_key: "remax")

    assert_equal "Remax", source.display_name
  end
end
