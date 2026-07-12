require "test_helper"

class NotifyNewListingsJobTest < ActiveJob::TestCase
  test "fans out and delivers events for run" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago, finished_at: Time.current)
    user = User.create!(
      first_name: "Demo",
      last_name: "User",
      email: "demo-job@example.com",
      password: "password123",
      password_confirmation: "password123",
      pushover_user_key: "u-abc123"
    )
    user.search_preferences.create!(name: "Centro rentals", location_query: "centro", notifications_enabled: true)
    Listing.create!(
      listing_source: source,
      scraping_run: run,
      title: "Apto Centro",
      in_scope: true,
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/centro/1",
      external_id: "1",
      location_text: "Centro, Montevideo"
    )

    delivered = []
    client = Object.new
    client.define_singleton_method(:deliver) { |**kwargs| delivered << kwargs; true }
    original_new = Notifications::PushoverClient.method(:new)
    Notifications::PushoverClient.define_singleton_method(:new) { client }

    NotifyNewListingsJob.perform_now(run.id)

    assert_equal 1, delivered.size
    assert_equal 1, NotificationEvent.where(status: "sent").count
  ensure
    Notifications::PushoverClient.define_singleton_method(:new, original_new)
  end
end
