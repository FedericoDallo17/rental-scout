# Ticket 015: Notification Pipeline MVP — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After each scrape run, create idempotent `NotificationEvent`s for new listings matching each notifications-enabled saved search, and deliver them via Pushover.

**Architecture:** `RunScrapersJob` enqueues `NotifyNewListingsJob(run_id)` after the orchestrator finishes. That job runs `Notifications::NewListingFanOut` (creates pending events, idempotent via the unique `idempotency_key`) then `Notifications::Deliverer` per event (delivers via `Notifications::PushoverClient`, records `sent`/`failed`/`skipped` on the event). Delivery never raises into the scrape path. The schema already supports all of this: `notification_events` (`event_kind`, `channel`, `status`, `idempotency_key` unique, `sent_at`, `delivery_error`), `users.pushover_user_key`, `search_preferences.notifications_enabled`.

**Tech Stack:** Rails 8, Solid Queue, Minitest, Net::HTTP (no HTTP-mocking gem — inject fakes, matching `test/services/sources/info_casas_api_adapter_test.rb` conventions).

## Global Constraints

- Channel decision (per adr-notifications-over-ranking): **Pushover** — the schema already stores `pushover_user_key`. Delivery goes through the `Notifications::Deliverer`/`PushoverClient` seam so email can replace it later without touching fan-out.
- Runtime prerequisite (NOT needed for tests): `PUSHOVER_API_TOKEN` env var (create an application at pushover.net). Without it, events are marked `failed` with a clear `delivery_error`; nothing crashes.
- Event `status` vocabulary — use exactly: `"pending"`, `"sent"`, `"failed"`, `"skipped"`. `event_kind` is `"new_listing"`. `channel` is `"pushover"`.
- Jobs inherit `ActiveJob::Base` with `queue_as :default` (repo convention, see `app/jobs/backfill_info_casas_coordinates_job.rb`).
- Full suite green after every commit: `bin/rails test` → `0 failures, 0 errors`.
- New-listing detection relies on `Listing#scraping_run` being set only at creation (see `app/services/scraping/listing_intake.rb:33` — `scraping_run` is assigned only when `was_new_record`). Do not change that behavior.

---

### Task 1: Fan-out service — create idempotent pending events

**Files:**
- Create: `app/services/notifications/new_listing_fan_out.rb`
- Create: `test/services/notifications/new_listing_fan_out_test.rb`

**Interfaces:**
- Consumes: `Listing.for_search_feed(search_preference)` (`app/models/listing.rb:18`), `Listing.where(scraping_run:)`.
- Produces: `Notifications::NewListingFanOut#call(scraping_run:) -> [NotificationEvent]` (the newly created pending events; empty array when nothing matches). Task 3 depends on this signature.

- [ ] **Step 1: Write the failing test**

Create `test/services/notifications/new_listing_fan_out_test.rb`:

```ruby
require "test_helper"

class Notifications::NewListingFanOutTest < ActiveSupport::TestCase
  setup do
    @source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    @run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago, finished_at: Time.current)
    @user = User.create!(
      first_name: "Demo", last_name: "User", email: "demo-notify@example.com",
      password: "password123", password_confirmation: "password123"
    )
    @search = @user.search_preferences.create!(
      name: "Centro rentals", location_query: "centro", notifications_enabled: true
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
    assert_equal 0, second.size
    assert_equal 1, NotificationEvent.count
  end

  test "skips searches with notifications disabled" do
    @search.update!(notifications_enabled: false)
    create_listing!(external_id: "n1", location_text: "Centro, Montevideo", scraping_run: @run)

    assert_equal [], Notifications::NewListingFanOut.new.call(scraping_run: @run)
    assert_equal 0, NotificationEvent.count
  end

  private

  def create_listing!(external_id:, location_text:, scraping_run:)
    Listing.create!(
      listing_source: @source,
      scraping_run: scraping_run,
      title: "Listing #{external_id}",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/x/#{external_id}",
      external_id: external_id,
      location_text: location_text,
      in_scope: true
    )
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/services/notifications/new_listing_fan_out_test.rb`
Expected: FAIL — `NameError: uninitialized constant Notifications`.

- [ ] **Step 3: Implement the service**

Create `app/services/notifications/new_listing_fan_out.rb`:

```ruby
module Notifications
  class NewListingFanOut
    def call(scraping_run:)
      new_listing_ids = Listing.where(scraping_run:).select(:id)
      created_events = []

      SearchPreference.where(notifications_enabled: true).find_each do |search|
        Listing.for_search_feed(search)
          .where(id: new_listing_ids)
          .includes(:listing_source)
          .find_each do |listing|
            event = create_event(search:, listing:)
            created_events << event if event
          end
      end

      created_events
    end

    private

    def create_event(search:, listing:)
      key = "new_listing/listing-#{listing.id}/search-#{search.id}"
      return nil if NotificationEvent.exists?(idempotency_key: key)

      NotificationEvent.create!(
        listing: listing,
        listing_source: listing.listing_source,
        search_preference: search,
        event_kind: "new_listing",
        channel: "pushover",
        status: "pending",
        idempotency_key: key
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      nil
    end
  end
end
```

(The `exists?` check is the normal idempotency path; the rescue covers the concurrent-race path where the uniqueness validation or index fires.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/notifications/new_listing_fan_out_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/notifications/new_listing_fan_out.rb test/services/notifications/new_listing_fan_out_test.rb
git commit -m "feat: fan out notification events for new matching listings"
```

---

### Task 2: Pushover client and per-event deliverer

**Files:**
- Create: `app/services/notifications/pushover_client.rb`
- Create: `app/services/notifications/deliverer.rb`
- Create: `test/services/notifications/deliverer_test.rb`

**Interfaces:**
- Produces: `Notifications::PushoverClient#deliver(user_key:, title:, message:, url: nil) -> true` (raises `Notifications::PushoverClient::DeliveryError` on any failure); `Notifications::Deliverer.new(client: PushoverClient.new)` with `#call(notification_event:)` which never raises and updates the event's `status`/`sent_at`/`delivery_error`. Task 3 depends on `Deliverer`.

- [ ] **Step 1: Write the failing deliverer test**

Create `test/services/notifications/deliverer_test.rb`:

```ruby
require "test_helper"

class Notifications::DelivererTest < ActiveSupport::TestCase
  setup do
    @source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    @user = User.create!(
      first_name: "Demo", last_name: "User", email: "demo-deliver@example.com",
      password: "password123", password_confirmation: "password123",
      pushover_user_key: "u-abc123"
    )
    @search = @user.search_preferences.create!(name: "Centro rentals", location_query: "centro")
    @listing = Listing.create!(
      listing_source: @source, title: "Apto Centro", price_cents: 2_500_000, currency: "UYU",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/centro/1", external_id: "1"
    )
    @event = NotificationEvent.create!(
      listing: @listing, listing_source: @source, search_preference: @search,
      event_kind: "new_listing", channel: "pushover", status: "pending",
      idempotency_key: "new_listing/listing-#{@listing.id}/search-#{@search.id}"
    )
  end

  test "marks the event sent and passes listing details to the client" do
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
    assert_equal @listing.canonical_url, delivered.first[:url]
  end

  test "marks the event failed when the client raises" do
    client = Object.new
    client.define_singleton_method(:deliver) do |**|
      raise Notifications::PushoverClient::DeliveryError, "pushover returned 400"
    end

    Notifications::Deliverer.new(client: client).call(notification_event: @event)

    @event.reload
    assert_equal "failed", @event.status
    assert_match "pushover returned 400", @event.delivery_error
    assert_nil @event.sent_at
  end

  test "marks the event skipped when the user has no pushover key" do
    @user.update!(pushover_user_key: nil)
    client = Object.new
    client.define_singleton_method(:deliver) { |**| flunk "must not deliver" }

    Notifications::Deliverer.new(client: client).call(notification_event: @event)

    assert_equal "skipped", @event.reload.status
    assert_match "no pushover_user_key", @event.delivery_error
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/services/notifications/deliverer_test.rb`
Expected: FAIL — `NameError: uninitialized constant Notifications::Deliverer` (and `PushoverClient` in the failure test).

- [ ] **Step 3: Implement client and deliverer**

Create `app/services/notifications/pushover_client.rb`:

```ruby
require "net/http"
require "uri"

module Notifications
  class PushoverClient
    ENDPOINT_URI = URI("https://api.pushover.net/1/messages.json")
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15

    class DeliveryError < StandardError; end

    def deliver(user_key:, title:, message:, url: nil)
      api_token = ENV["PUSHOVER_API_TOKEN"]
      raise DeliveryError, "PUSHOVER_API_TOKEN is not set" if api_token.blank?

      response = post_message(api_token:, user_key:, title:, message:, url:)
      raise DeliveryError, "pushover returned #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      true
    end

    private

    def post_message(api_token:, user_key:, title:, message:, url:)
      Net::HTTP.start(
        ENDPOINT_URI.host,
        ENDPOINT_URI.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Post.new(ENDPOINT_URI)
        request.set_form_data({ token: api_token, user: user_key, title: title, message: message, url: url }.compact)
        http.request(request)
      end
    end
  end
end
```

Create `app/services/notifications/deliverer.rb`:

```ruby
module Notifications
  class Deliverer
    def initialize(client: PushoverClient.new)
      @client = client
    end

    def call(notification_event:)
      user = notification_event.search_preference&.user
      listing = notification_event.listing

      if user&.pushover_user_key.blank?
        notification_event.update!(status: "skipped", delivery_error: "user has no pushover_user_key")
        return
      end

      @client.deliver(
        user_key: user.pushover_user_key,
        title: "New match: #{notification_event.search_preference.name}",
        message: "#{listing.title} — #{formatted_price(listing)}",
        url: listing.canonical_url
      )
      notification_event.update!(status: "sent", sent_at: Time.current, delivery_error: nil)
    rescue StandardError => error
      notification_event.update!(status: "failed", delivery_error: "#{error.class}: #{error.message}")
    end

    private

    def formatted_price(listing)
      return "price unknown" if listing.price_cents.blank?

      "#{listing.currency} #{listing.price_cents / 100}"
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/notifications/deliverer_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/notifications/pushover_client.rb app/services/notifications/deliverer.rb test/services/notifications/deliverer_test.rb
git commit -m "feat: deliver notification events via pushover"
```

---

### Task 3: Wire into the scrape run

**Files:**
- Create: `app/jobs/notify_new_listings_job.rb`
- Modify: `app/jobs/run_scrapers_job.rb`
- Create: `test/jobs/notify_new_listings_job_test.rb`
- Modify: `test/jobs/run_scrapers_job_test.rb`

**Interfaces:**
- Consumes: `Notifications::NewListingFanOut#call(scraping_run:)` (Task 1), `Notifications::Deliverer#call(notification_event:)` (Task 2), `Scraping::RunOrchestrator#call -> ScrapingRun` (returns the run — see `app/services/scraping/run_orchestrator.rb:15`).
- Produces: `NotifyNewListingsJob.perform_later(scraping_run_id)`.

- [ ] **Step 1: Write the failing job test**

Create `test/jobs/notify_new_listings_job_test.rb`:

```ruby
require "test_helper"

class NotifyNewListingsJobTest < ActiveJob::TestCase
  test "fans out and delivers events for the given run" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago, finished_at: Time.current)
    user = User.create!(
      first_name: "Demo", last_name: "User", email: "demo-job@example.com",
      password: "password123", password_confirmation: "password123",
      pushover_user_key: "u-abc123"
    )
    user.search_preferences.create!(name: "Centro rentals", location_query: "centro", notifications_enabled: true)
    Listing.create!(
      listing_source: source, scraping_run: run, title: "Apto Centro", in_scope: true,
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/centro/1",
      external_id: "1", location_text: "Centro, Montevideo"
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
```

Also add to `test/jobs/run_scrapers_job_test.rb` (inside the class; keep existing tests):

```ruby
test "enqueues notification fan-out after the run" do
  RunScrapersJob.perform_now

  assert_enqueued_with(job: NotifyNewListingsJob)
end
```

(If `RunScrapersJob.perform_now` in the existing test file needs adapter stubbing to avoid live HTTP, follow whatever stubbing pattern that file already uses for the orchestrator; the assertion only cares that the follow-up job is enqueued with the run id.)

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/jobs/notify_new_listings_job_test.rb test/jobs/run_scrapers_job_test.rb`
Expected: FAIL — `NameError: uninitialized constant NotifyNewListingsJob`.

- [ ] **Step 3: Implement**

Create `app/jobs/notify_new_listings_job.rb`:

```ruby
class NotifyNewListingsJob < ActiveJob::Base
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(scraping_run_id)
    scraping_run = ScrapingRun.find(scraping_run_id)
    events = Notifications::NewListingFanOut.new.call(scraping_run:)
    deliverer = Notifications::Deliverer.new
    events.each { |event| deliverer.call(notification_event: event) }
  end
end
```

Modify `app/jobs/run_scrapers_job.rb` to:

```ruby
class RunScrapersJob < ActiveJob::Base
  queue_as :default

  def perform
    run = Scraping::RunOrchestrator.new.call
    NotifyNewListingsJob.perform_later(run.id)
  end
end
```

(Check the current file first — if it differs from this shape beyond the orchestrator call, preserve its existing behavior and only add the `NotifyNewListingsJob.perform_later(run.id)` line after the orchestrator call.)

- [ ] **Step 4: Run the full suite**

Run: `bin/rails test`
Expected: PASS, `0 failures, 0 errors`.

- [ ] **Step 5: Commit, update state docs**

```bash
git add app/jobs/notify_new_listings_job.rb app/jobs/run_scrapers_job.rb test/jobs/notify_new_listings_job_test.rb test/jobs/run_scrapers_job_test.rb
git commit -m "feat: notify users after each scrape run"
```

Then update `.ai/STATUS.md` (Ticket 015 done; note the `PUSHOVER_API_TOKEN` runtime prerequisite under Human Input Needed until credentials exist) and commit as `docs: mark ticket 015 complete`.

**Manual end-to-end validation (requires credentials, do NOT automate):** set `PUSHOVER_API_TOKEN`, set a real `pushover_user_key` on your user, start `bin/dev` with Solid Queue running, trigger `RunScrapersJob.perform_later` from `bin/rails console`, and confirm a push arrives and the event row shows `status: "sent"`.
