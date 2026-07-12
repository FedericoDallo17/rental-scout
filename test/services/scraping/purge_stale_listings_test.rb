require "test_helper"

class Scraping::PurgeStaleListingsTest < ActiveSupport::TestCase
  setup do
    @source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    @user = User.create!(
      first_name: "Demo",
      last_name: "User",
      email: "purge-demo@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @search = @user.search_preferences.create!(name: "Centro rentals", location_query: "centro")
  end

  test "deletes stale listings notification events and nullifies seen listings" do
    stale = create_listing!(external_id: "stale")
    fresh = create_listing!(external_id: "fresh")
    stale.update_columns(updated_at: 8.days.ago)
    fresh.update_columns(updated_at: 6.days.ago)
    event = create_notification_event!(stale)
    seen_listing = create_seen_listing!(stale)

    result = Scraping::PurgeStaleListings.new.call(now: Time.current)

    assert_equal 1, result.listings_deleted_count
    assert_equal 1, result.notification_events_deleted_count
    assert_not Listing.exists?(stale.id)
    assert_not NotificationEvent.exists?(event.id)
    assert Listing.exists?(fresh.id)
    assert_nil seen_listing.reload.listing_id
  end

  test "does not delete listings seen within seven days" do
    fresh = create_listing!(external_id: "fresh")
    fresh.update_columns(updated_at: 7.days.ago + 1.second)

    result = Scraping::PurgeStaleListings.new.call(now: Time.current)

    assert_equal 0, result.listings_deleted_count
    assert Listing.exists?(fresh.id)
  end

  test "logs purge counts" do
    stale = create_listing!(external_id: "stale")
    stale.update_columns(updated_at: 8.days.ago)
    create_notification_event!(stale)
    logged = []
    original_info = Rails.logger.method(:info)
    Rails.logger.define_singleton_method(:info) { |message| logged << message }

    Scraping::PurgeStaleListings.new.call(now: Time.current)

    assert_match(/deleted 1 stale listings/, logged.join)
    assert_match(/1 notification events/, logged.join)
  ensure
    Rails.logger.define_singleton_method(:info, original_info) if original_info
  end

  private

  def create_listing!(external_id:)
    Listing.create!(
      listing_source: @source,
      title: "Listing #{external_id}",
      canonical_url: "https://example.test/listings/#{external_id}",
      external_id: external_id,
      in_scope: true
    )
  end

  def create_notification_event!(listing)
    NotificationEvent.create!(
      listing: listing,
      listing_source: @source,
      search_preference: @search,
      event_kind: "new_listing",
      channel: "pushover",
      status: "sent",
      idempotency_key: "new_listing/listing-#{listing.id}/search-#{@search.id}"
    )
  end

  def create_seen_listing!(listing)
    SeenListing.create!(
      listing_source: @source,
      listing: listing,
      external_id: listing.external_id,
      canonical_url: listing.canonical_url,
      first_seen_at: 9.days.ago,
      last_seen_at: 8.days.ago
    )
  end
end
