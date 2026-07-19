require "test_helper"

class ScrapingRunsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected away scraping runs" do
    get admin_root_path

    assert_redirected_to new_user_session_path
  end

  test "admin sees recent scraping run summaries" do
    user = create_user!(email: "runs@example.com", admin: true)
    sign_in user
    source = ListingSource.find_or_create_by!(adapter_key: "info_casas_api") do |listing_source|
      listing_source.name = "InfoCasas API"
    end
    run = ScrapingRun.create!(
      status: "completed_with_failures",
      reconciliation: true,
      started_at: 2.hours.ago,
      finished_at: 1.hour.ago,
      listings_seen_count: 12,
      listings_created_count: 3,
      error_message: "top-level warning"
    )
    run.scraping_source_runs.create!(
      listing_source: source,
      status: "failed",
      started_at: 2.hours.ago,
      finished_at: 90.minutes.ago,
      listings_seen_count: 4,
      listings_created_count: 1,
      error_message: "provider timeout"
    )

    get admin_root_path

    assert_response :success
    assert_includes response.body, "Scraping Runs"
    assert_includes response.body, "Inventory reconciliation"
    assert_includes response.body, "Completed with failures"
    assert_includes response.body, "12 seen"
    assert_includes response.body, "3 new"
    assert_includes response.body, "top-level warning"
    assert_includes response.body, "InfoCasas"
    assert_not_includes response.body, "InfoCasas API"
    assert_includes response.body, "provider timeout"
    assert_select ".runs-workbench"
    assert_select "a[href='#{listings_path}']", text: "Feed"
    assert_select ".source-run__timeline", text: /Started/
  end

  test "admin sees listing source activation controls" do
    user = create_user!(email: "source-controls@example.com", admin: true)
    sign_in user
    ListingSource.delete_all
    remax = ListingSource.create!(name: "Remax", adapter_key: "remax", active: false)
    info_casas = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api", active: true)

    get admin_root_path

    assert_response :success
    assert_select ".source-controls"
    assert_select ".source-controls__explanation", text: /Active sources are checked on the next run/
    assert_select ".source-controls[aria-label='Listing sources']" do
      assert_select ".source-control-card", count: 2
      assert_select ".source-control-card", text: /Remax/
      assert_select ".source-control-card", text: /Inactive/
      assert_select ".source-control-card", text: /InfoCasas/
    end
    assert_not_includes response.body, "info_casas_api"
    assert_select "form[action='#{admin_listing_source_path(remax)}'] input[name='_method'][value='patch']", count: 1
    assert_select "form[action='#{admin_listing_source_path(info_casas)}'] button", text: "Deactivate"
  end

  test "admin sees inventory location quality metrics" do
    user = create_user!(email: "location-quality@example.com", admin: true)
    source = ListingSource.create!(name: "Location Metrics", adapter_key: "location_metrics")
    Listing.create!(listing_source: source, title: "Fallback", canonical_url: "https://example.test/location-fallback", location_resolution_status: "fallback")
    Listing.create!(listing_source: source, title: "Unresolved", canonical_url: "https://example.test/location-unresolved", location_resolution_status: "unresolved")
    sign_in user

    get admin_root_path

    assert_response :success
    assert_select "#location-quality-heading", text: "How reliable is the location?"
    assert_select ".location-quality-intro", text: /official zones/
    assert_select ".run-card__facts", text: /1 properties have no coordinates/
    assert_select ".run-card__facts", text: /1 properties cannot be located/
    assert_select ".run-card__facts", text: /supplied neighborhood disagrees/
    assert_select ".location-quality-table tr", text: /Location Metrics/
    assert_select ".location-quality-table tr", text: /0%/
  end

  test "signed in user sees only their persisted matches for a run" do
    user = create_user!(email: "matches@example.com")
    other_user = create_user!(email: "other-matches@example.com")
    source = ListingSource.create!(name: "Match Source", adapter_key: "match_source")
    run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago)
    own_search = user.search_preferences.create!(name: "My Centro search", location_query: "centro")
    other_search = other_user.search_preferences.create!(name: "Private search", location_query: "centro")
    own_listing = Listing.create!(listing_source: source, scraping_run: run, title: "My matching rental", canonical_url: "https://example.com/own")
    other_listing = Listing.create!(listing_source: source, scraping_run: run, title: "Someone else's rental", canonical_url: "https://example.com/other")
    create_event!(own_search, own_listing, "own")
    create_event!(other_search, other_listing, "other")
    sign_in user

    get scraping_run_path(run)

    assert_response :success
    assert_includes response.body, "My matching rental"
    assert_includes response.body, "My Centro search"
    assert_not_includes response.body, "Someone else&#39;s rental"
    assert_not_includes response.body, "Private search"
  end

  test "signed in user sees a runs tab containing only runs with their matches" do
    user = create_user!(email: "user-runs@example.com")
    other_user = create_user!(email: "other-user-runs@example.com")
    source = ListingSource.create!(name: "User Runs Source", adapter_key: "user_runs_source")
    own_run = ScrapingRun.create!(status: "succeeded", started_at: 2.minutes.ago)
    other_run = ScrapingRun.create!(status: "succeeded", started_at: 1.minute.ago)
    own_search = user.search_preferences.create!(name: "Own search", location_query: "centro")
    other_search = other_user.search_preferences.create!(name: "Other search", location_query: "centro")
    2.times do |index|
      listing = Listing.create!(listing_source: source, scraping_run: own_run, title: "Own match #{index}", canonical_url: "https://example.com/own-#{index}")
      create_event!(own_search, listing, "own-run-#{index}")
    end
    other_listing = Listing.create!(listing_source: source, scraping_run: other_run, title: "Other match", canonical_url: "https://example.com/other-run")
    create_event!(other_search, other_listing, "other-run")
    sign_in user

    get scraping_runs_path

    assert_response :success
    assert_select "#location-quality-heading"
    assert_select "a[href='#{scraping_run_path(own_run)}']", text: "View these listings"
    assert_includes response.body, "2 matches"
    assert_not_includes response.body, "Run ##{other_run.id}"
  end

  test "admin toggles listing source active state" do
    user = create_user!(email: "source-toggle@example.com", admin: true)
    sign_in user
    source = ListingSource.create!(name: "Housi", adapter_key: "housi_toggle", active: false)

    patch admin_listing_source_path(source), params: { listing_source: { active: "1" } }

    assert_redirected_to admin_root_path
    assert_equal true, source.reload.active
  end

  test "guest cannot toggle listing source active state" do
    source = ListingSource.create!(name: "Housi", adapter_key: "housi_guest_toggle", active: false)

    patch admin_listing_source_path(source), params: { listing_source: { active: "1" } }

    assert_redirected_to new_user_session_path
    assert_equal false, source.reload.active
  end

  test "admin header links the admin tab" do
    user = create_user!(email: "runs-link@example.com", admin: true)
    sign_in user

    get listings_path

    assert_response :success
    assert_select "a[href='#{admin_root_path}']", text: "Admin"
    get admin_root_path
    assert_select "a[href='#{admin_users_path}']", text: "Users"
    assert_select "form[action='#{admin_maintenance_path}']", count: 4
    assert_select "button.maintenance-action-card", count: 4
    assert_select ".maintenance-action-card__cta", count: 0
  end

  test "normal user cannot see or access admin operations" do
    user = create_user!(email: "normal-user@example.com")
    source = ListingSource.create!(name: "Protected Source", adapter_key: "protected_source", active: false)
    sign_in user

    get listings_path
    assert_response :success
    assert_select "a[href='#{scraping_runs_path}']", text: "Runs"
    assert_select "a[href='#{admin_root_path}']", count: 0

    get admin_root_path
    assert_response :not_found

    patch admin_listing_source_path(source), params: { listing_source: { active: "1" } }
    assert_response :not_found
    assert_not source.reload.active?
  end

  private

  def create_user!(email:, admin: false)
    User.create!(
      first_name: "Runs",
      last_name: "User",
      email: email,
      password: "password123",
      password_confirmation: "password123",
      admin:
    )
  end

  def create_event!(search, listing, suffix)
    NotificationEvent.create!(
      listing:,
      listing_source: listing.listing_source,
      search_preference: search,
      event_kind: "new_listing",
      channel: "pushover",
      status: "sent",
      idempotency_key: "controller-match-#{suffix}"
    )
  end
end
