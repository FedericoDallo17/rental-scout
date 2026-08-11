require "test_helper"

class Notifications::BrowserDelivererTest < ActiveSupport::TestCase
  test "delivers one browser notification per listing with its details" do
    user = create_push_test_user!
    source = ListingSource.create!(name: "Browser Source", adapter_key: "browser_source")
    search = user.search_preferences.create!(name: "Centro", location_query: "centro")
    listing = Listing.create!(
      listing_source: source, title: "Apto Centro", external_id: "browser-1",
      canonical_url: "https://example.com/browser-1", price_cents: 25_000_00, currency: "UYU"
    )
    events = 2.times.map do |index|
      NotificationEvent.create!(
        listing:, listing_source: source, search_preference: search,
        event_kind: "new_listing", channel: "pushover", status: "pending",
        idempotency_key: "browser-delivery-#{index}"
      )
    end
    deliveries = []
    client = Object.new
    client.define_singleton_method(:deliver) do |**attributes|
      deliveries << attributes
      Notifications::WebPushClient::DeliveryResult.new(delivered_count: 1, failed_count: 0)
    end

    Notifications::BrowserDeliverer.new(client:).call(user:, events:)

    assert_equal 1, deliveries.size
    assert_match "Apto Centro", deliveries.first[:message]
    assert_equal listing.canonical_url, deliveries.first[:url]
    assert events.all? { |event| event.reload.status == "sent" }
    assert events.all? { |event| event.channel == "web_push" }
  end
end
