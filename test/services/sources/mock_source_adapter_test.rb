require "test_helper"

class Sources::MockSourceAdapterTest < ActiveSupport::TestCase
  test "returns a curated deterministic Montevideo dataset" do
    listings = Sources::MockSourceAdapter.new.fetch_listings

    assert_equal 10, listings.size

    assert_equal %i[bedrooms canonical_url description external_id location_text price_cents square_meters title].sort,
                 listings.first.keys.sort

    assert_includes listings.map { |listing| listing[:location_text] }, "Pocitos, Montevideo"
    assert_includes listings.map { |listing| listing[:location_text] }, "Cordón, Montevideo"
    assert_equal listings.size, listings.map { |listing| listing[:external_id] }.uniq.size
    assert_equal listings.size, listings.map { |listing| listing[:canonical_url] }.uniq.size
    assert listings.all? { |listing| listing[:canonical_url].start_with?("https://example.test/listings/") }
    assert listings.all? { |listing| listing[:description].present? }
  end
end
