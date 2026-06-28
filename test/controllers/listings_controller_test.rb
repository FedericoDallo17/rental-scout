require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  test "shows scraped listings" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1")

    get listings_path

    assert_response :success
    assert_includes response.body, "Apto Pocitos"
    assert_includes response.body, "Mock Source"
  end
end
