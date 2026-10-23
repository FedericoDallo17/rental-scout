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

  test "delivers one summary when a listing matches overlapping searches" do
    source = ListingSource.create!(name: "Summary Source", adapter_key: "summary_source")
    run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago, finished_at: Time.current)
    user = User.create!(first_name: "Demo", last_name: "User", email: "summary@example.com", password: "password123", pushover_user_key: "u-summary")
    2.times { |index| user.search_preferences.create!(name: "Centro #{index}", location_query: "centro", notifications_enabled: true) }
    Listing.create!(listing_source: source, scraping_run: run, title: "Apto Centro", in_scope: true, canonical_url: "https://example.com/summary", external_id: "summary", location_text: "Centro")

    delivered = []
    client = Object.new
    client.define_singleton_method(:deliver) { |**kwargs| delivered << kwargs; true }
    original_new = Notifications::PushoverClient.method(:new)
    Notifications::PushoverClient.define_singleton_method(:new) { client }

    NotifyNewListingsJob.perform_now(run.id)

    assert_equal 1, delivered.size
    assert_match "1 new property", delivered.first[:message]
    assert_equal 2, NotificationEvent.where(status: "sent").count
  ensure
    Notifications::PushoverClient.define_singleton_method(:new, original_new)
  end

  test "delivers a listing notification to the browser instead of a run summary" do
    source = ListingSource.create!(name: "Browser Job Source", adapter_key: "browser_job_source")
    run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago, finished_at: Time.current)
    user = create_push_test_user!
    user.push_subscriptions.create!(
      endpoint: "https://push.example.com/#{SecureRandom.hex(8)}", p256dh: "public-key", auth: "auth-secret"
    )
    search = user.search_preferences.create!(name: "Centro", location_query: "centro", notifications_enabled: true)
    SearchZone.where(search_preference: search).delete_all
    Listing.create!(
      listing_source: source, scraping_run: run, title: "Apto Browser", in_scope: true,
      canonical_url: "https://example.com/browser-job", external_id: "browser-job",
      location_text: "Centro"
    )
    NotificationEvent.where(listing: Listing.where(scraping_run: run)).delete_all
    deliveries = []
    client = Object.new
    client.define_singleton_method(:deliver) do |**attributes|
      deliveries << attributes
      Notifications::WebPushClient::DeliveryResult.new(delivered_count: 1, failed_count: 0)
    end
    original_new = Notifications::WebPushClient.method(:new)
    Notifications::WebPushClient.define_singleton_method(:new) { client }

    NotifyNewListingsJob.perform_now(run.id)

    assert_equal 1, deliveries.size
    assert_equal "https://example.com/browser-job", deliveries.first[:url]
    assert_match "Apto Browser", deliveries.first[:message]
    assert_equal 1, NotificationEvent.where(status: "sent", channel: "web_push").count
  ensure
    Notifications::WebPushClient.define_singleton_method(:new, original_new)
  end
end
