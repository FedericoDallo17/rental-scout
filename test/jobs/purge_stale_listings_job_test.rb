require "test_helper"

class PurgeStaleListingsJobTest < ActiveJob::TestCase
  test "purges stale listings" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    stale = Listing.create!(
      listing_source: source,
      title: "Stale listing",
      canonical_url: "https://example.test/listings/stale",
      external_id: "stale"
    )
    stale.update_columns(updated_at: 8.days.ago)

    result = PurgeStaleListingsJob.perform_now

    assert_equal 1, result.listings_deleted_count
    assert_not Listing.exists?(stale.id)
  end
end
