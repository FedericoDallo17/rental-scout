require "test_helper"

class Notifications::DelivererTest < ActiveSupport::TestCase
  setup do
    @source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    @user = User.create!(
      first_name: "Demo",
      last_name: "User",
      email: "demo-deliver@example.com",
      password: "password123",
      password_confirmation: "password123",
      pushover_user_key: "u-abc123"
    )
    @search = @user.search_preferences.create!(name: "Centro rentals", location_query: "centro")
    @listing = Listing.create!(
      listing_source: @source,
      title: "Apto Centro",
      price_cents: 2_500_000,
      currency: "UYU",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/centro/1",
      external_id: "1"
    )
    @event = NotificationEvent.create!(
      listing: @listing,
      listing_source: @source,
      search_preference: @search,
      event_kind: "new_listing",
      channel: "pushover",
      status: "pending",
      idempotency_key: "new_listing/listing-#{@listing.id}/search-#{@search.id}"
    )
  end

  test "marks event sent and passes listing details to client" do
    delivered = []
    client = Object.new
    client.define_singleton_method(:deliver) { |**kwargs| delivered << kwargs; true }

    Notifications::Deliverer.new(client: client).call(notification_event: @event)

    @event.reload
    assert_equal "sent", @event.status
    assert_not_nil @event.sent_at
    assert_nil @event.delivery_error
    assert_equal "u-abc123", delivered.first[:user_key]
    assert_match "Centro rentals", delivered.first[:title]
    assert_match "Apto Centro", delivered.first[:message]
    assert_match "UYU 25.000", delivered.first[:message]
    assert_equal @listing.canonical_url, delivered.first[:url]
  end

  test "marks event failed when client raises" do
    client = Object.new
    client.define_singleton_method(:deliver) do |**|
      raise Notifications::PushoverClient::DeliveryError, "pushover unavailable"
    end

    Notifications::Deliverer.new(client: client).call(notification_event: @event)

    @event.reload
    assert_equal "failed", @event.status
    assert_match "pushover unavailable", @event.delivery_error
    assert_nil @event.sent_at
  end

  test "marks event skipped when user has no pushover key" do
    @user.update!(pushover_user_key: nil)
    client = Object.new
    client.define_singleton_method(:deliver) { |**| raise "should not deliver" }

    Notifications::Deliverer.new(client: client).call(notification_event: @event)

    @event.reload
    assert_equal "skipped", @event.status
    assert_match "pushover_user_key", @event.delivery_error
    assert_nil @event.sent_at
  end
end
