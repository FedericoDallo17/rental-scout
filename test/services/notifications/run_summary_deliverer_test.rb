require "test_helper"

class Notifications::RunSummaryDelivererTest < ActiveSupport::TestCase
  test "delivers the summary in the user's language" do
    user = User.create!(
      first_name: "Demo", last_name: "User", email: "spanish-summary@example.com",
      password: "password123", password_confirmation: "password123",
      pushover_user_key: "u-abc123", locale: "es"
    )
    run = ScrapingRun.create!(status: "succeeded", started_at: Time.current)
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    search = user.search_preferences.create!(name: "Centro", location_query: "centro")
    events = 2.times.map do |index|
      listing = Listing.create!(
        listing_source: source, title: "Listing #{index}", external_id: index.to_s,
        canonical_url: "https://example.com/#{index}"
      )
      NotificationEvent.create!(
        listing: listing, listing_source: source, search_preference: search,
        event_kind: "new_listing", channel: "pushover", status: "pending",
        idempotency_key: "summary-#{index}"
      )
    end
    delivered = []
    client = Object.new
    client.define_singleton_method(:deliver) { |**kwargs| delivered << kwargs; true }
    Notifications::RunSummaryDeliverer.new(client: client).call(user: user, events: events, scraping_run: run)

    assert_equal "Sonó un timbre", delivered.first[:title]
    assert_equal "Aparecieron 2 propiedades nuevas para tus búsquedas.", delivered.first[:message]
    uri = URI.parse(delivered.first[:url])
    assert_equal "/notification_results", uri.path
    payload = Rails.application.message_verifier(:notification_results).verified(
      Rack::Utils.parse_query(uri.query).fetch("token"), purpose: :notification_results
    )
    assert_equal({ "user_id" => user.id, "scraping_run_id" => run.id, "locale" => "es" }, payload)
  end
end
