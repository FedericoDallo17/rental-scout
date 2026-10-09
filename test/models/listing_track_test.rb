require "test_helper"

class ListingTrackTest < ActiveSupport::TestCase
  setup do
    @user = create_push_test_user!
    @source = ListingSource.create!(name: "Tracking source", adapter_key: "tracking_source")
    @listing = Listing.create!(listing_source: @source, title: "Saved apartment", canonical_url: "https://example.test/tracking", external_id: "tracking", square_meters: 60)
  end

  test "personal history survives the inventory purge" do
    track = @user.listing_tracks.build(favorite: true, contacted_on: Date.current, visited_on: Date.yesterday)
    track.capture_listing(@listing)
    track.save!
    @listing.update_columns(updated_at: 8.days.ago)

    Scraping::PurgeStaleListings.new.call

    assert_nil track.reload.listing_id
    assert_equal "Saved apartment", track.snapshot.fetch("title")
    assert_equal 60, track.snapshot.fetch("square_meters")
    assert_equal Date.current, track.contacted_on
    assert_equal Date.yesterday, track.visited_on
    assert track.favorite?
  end

  test "identity is unique per user but another user can track the same apartment" do
    track = @user.listing_tracks.build(favorite: true)
    track.capture_listing(@listing)
    track.save!
    duplicate = @user.listing_tracks.build
    duplicate.capture_listing(@listing)
    assert_not duplicate.valid?

    other = create_push_test_user!.listing_tracks.build
    other.capture_listing(@listing)
    assert other.valid?
  end

  test "invalid dates cannot silently erase history" do
    track = @user.listing_tracks.build(contacted_on: "not-a-date")
    track.capture_listing(@listing)
    assert_not track.valid?
    assert track.errors[:contacted_on].any?
  end
end
