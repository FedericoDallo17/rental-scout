require "test_helper"

class ScrapingRunsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected away scraping runs" do
    get scraping_runs_path

    assert_redirected_to new_user_session_path
  end

  test "signed in user sees recent scraping run summaries" do
    user = create_user!(email: "runs@example.com")
    sign_in user
    source = ListingSource.find_or_create_by!(adapter_key: "info_casas_api") do |listing_source|
      listing_source.name = "InfoCasas API"
    end
    run = ScrapingRun.create!(
      status: "completed_with_failures",
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

    get scraping_runs_path

    assert_response :success
    assert_includes response.body, "Scraping Runs"
    assert_includes response.body, "completed_with_failures"
    assert_includes response.body, "12 seen"
    assert_includes response.body, "3 new"
    assert_includes response.body, "top-level warning"
    assert_includes response.body, "InfoCasas API"
    assert_includes response.body, "provider timeout"
    assert_select ".runs-workbench"
    assert_select "a[href='#{listings_path}']", text: "Feed"
    assert_select ".source-run__timeline", text: /Started/
  end

  test "signed in user sees listing source activation controls" do
    user = create_user!(email: "source-controls@example.com")
    sign_in user
    ListingSource.delete_all
    remax = ListingSource.create!(name: "Remax", adapter_key: "remax", active: false)
    info_casas = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api", active: true)

    get scraping_runs_path

    assert_response :success
    assert_select ".source-controls"
    assert_select ".source-control-card", count: 2
    assert_select ".source-control-card", text: /Remax/
    assert_select ".source-control-card", text: /Inactive/
    assert_select "form[action='#{listing_source_path(remax)}'] input[name='_method'][value='patch']", count: 1
    assert_select "form[action='#{listing_source_path(info_casas)}'] button", text: "Deactivate"
  end

  test "signed in user toggles listing source active state" do
    user = create_user!(email: "source-toggle@example.com")
    sign_in user
    source = ListingSource.create!(name: "Housi", adapter_key: "housi_toggle", active: false)

    patch listing_source_path(source), params: { listing_source: { active: "1" } }

    assert_redirected_to scraping_runs_path
    assert_equal true, source.reload.active
  end

  test "guest cannot toggle listing source active state" do
    source = ListingSource.create!(name: "Housi", adapter_key: "housi_guest_toggle", active: false)

    patch listing_source_path(source), params: { listing_source: { active: "1" } }

    assert_redirected_to new_user_session_path
    assert_equal false, source.reload.active
  end

  test "signed in app header links scraping runs" do
    user = create_user!(email: "runs-link@example.com")
    sign_in user

    get listings_path

    assert_response :success
    assert_select "a[href='#{scraping_runs_path}']", text: "Runs"
  end

  private

  def create_user!(email:)
    User.create!(
      first_name: "Runs",
      last_name: "User",
      email: email,
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
