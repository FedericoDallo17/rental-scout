require "test_helper"

class Listings::SavedSearchMatchesTest < ActiveSupport::TestCase
  test "indexes deduplicated listing matches in both directions" do
    user = create_user!("aggregate-index@example.com")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "aggregate_index_source")
    pocitos = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    affordable = user.search_preferences.create!(name: "Affordable", location_query: "Pocitos", max_price_cents: 4_000_000)
    shared = Listing.create!(listing_source: source, title: "Shared", canonical_url: "https://example.test/shared-aggregate", location_text: "Pocitos", price_cents: 3_000_000, currency: "UYU", in_scope: true)
    only_location = Listing.create!(listing_source: source, title: "Only location", canonical_url: "https://example.test/location-aggregate", location_text: "Pocitos", price_cents: 5_000_000, currency: "UYU", in_scope: true)

    result = Listings::SavedSearchMatches.new([pocitos, affordable]).call

    assert_equal [shared.id, only_location.id].sort, result.listing_ids_by_search_id.fetch(pocitos.id).sort
    assert_equal [shared.id], result.listing_ids_by_search_id.fetch(affordable.id)
    assert_equal [pocitos.id, affordable.id].sort, result.search_ids_by_listing_id.fetch(shared.id).sort
    assert_equal [pocitos.id], result.search_ids_by_listing_id.fetch(only_location.id)
  end

  private

  def create_user!(email)
    User.create!(first_name: "Aggregate", last_name: "User", email:, password: "password123", password_confirmation: "password123")
  end
end
