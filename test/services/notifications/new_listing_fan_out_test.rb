require "test_helper"

class Notifications::NewListingFanOutTest < ActiveSupport::TestCase
  setup do
    @source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    @run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago, finished_at: Time.current)
    @user = User.create!(
      first_name: "Demo",
      last_name: "User",
      email: "demo-notify@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @search = @user.search_preferences.create!(
      name: "Centro rentals",
      location_query: "centro",
      notifications_enabled: true
    )
  end

  test "creates one pending event per matching new listing and search" do
    matching = create_listing!(external_id: "n1", location_text: "Centro, Montevideo", scraping_run: @run)
    create_listing!(external_id: "old1", location_text: "Centro, Montevideo", scraping_run: nil)
    create_listing!(external_id: "n2", location_text: "Carrasco, Montevideo", scraping_run: @run)

    events = Notifications::NewListingFanOut.new.call(scraping_run: @run)

    assert_equal 1, events.size
    event = events.first
    assert_equal matching, event.listing
    assert_equal @search, event.search_preference
    assert_equal "new_listing", event.event_kind
    assert_equal "pending", event.status
    assert_equal "pushover", event.channel
    assert_equal "new_listing/listing-#{matching.id}/search-#{@search.id}", event.idempotency_key
  end

  test "is idempotent across repeated runs" do
    create_listing!(external_id: "n1", location_text: "Centro, Montevideo", scraping_run: @run)

    first = Notifications::NewListingFanOut.new.call(scraping_run: @run)
    second = Notifications::NewListingFanOut.new.call(scraping_run: @run)

    assert_equal 1, first.size
    assert_empty second
    assert_equal 1, NotificationEvent.count
  end

  test "ignores searches with notifications disabled" do
    @search.update!(notifications_enabled: false)
    create_listing!(external_id: "n1", location_text: "Centro, Montevideo", scraping_run: @run)

    events = Notifications::NewListingFanOut.new.call(scraping_run: @run)

    assert_empty events
    assert_equal 0, NotificationEvent.count
  end

  private

  def create_listing!(external_id:, location_text:, scraping_run:)
    Listing.create!(
      listing_source: @source,
      scraping_run: scraping_run,
      title: "Listing #{external_id}",
      canonical_url: "https://www.infocasas.com.uy/listings/#{external_id}",
      external_id: external_id,
      location_text: location_text,
      in_scope: true
    )
  end
end
