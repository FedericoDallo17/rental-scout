require "test_helper"

class Sources::MockSourceAdapterTest < ActiveSupport::TestCase
  test "returns normalized listing hashes" do
    listings = Sources::MockSourceAdapter.new.fetch_listings

    assert_equal 1, listings.size

    assert_equal %i[canonical_url external_id location_text price_cents square_meters title].sort, listings.first.keys.sort
    assert_equal "Pocitos", listings.first[:location_text]
  end
end
