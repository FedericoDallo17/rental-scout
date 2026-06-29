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

  test "fetch_listings returns listings isolated from consumer mutation across calls" do
    adapter = Sources::MockSourceAdapter.new

    original_listing = adapter.fetch_listings.first
    original_title = original_listing[:title].dup
    original_description = original_listing[:description].dup

    original_listing[:title] << " mutado"
    original_listing[:description] << " mutada"

    fresh_listing = adapter.fetch_listings.first

    assert_equal original_title, fresh_listing[:title]
    assert_equal original_description, fresh_listing[:description]
  end
end
