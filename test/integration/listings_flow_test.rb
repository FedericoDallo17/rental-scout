require "test_helper"

class ListingsFlowTest < ActionDispatch::IntegrationTest
  test "root redirects into listings portal" do
    get root_url

    assert_response :success
    assert_includes response.body, "Scraped Apartments"
  end

  test "listings index is available" do
    get listings_url

    assert_response :success
    assert_includes response.body, "Scraped Apartments"
  end
end
