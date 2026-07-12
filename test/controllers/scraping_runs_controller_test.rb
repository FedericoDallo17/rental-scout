require "test_helper"

class ScrapingRunsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected away from scraping runs" do
    get scraping_runs_path

    assert_redirected_to new_user_session_path
  end

  test "signed in user sees recent scraping run summaries" do
    user = create_user!(email: "runs@example.com")
    sign_in user

    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
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
  end

  test "signed in app header links to scraping runs" do
    user = create_user!(email: "runs-link@example.com")
    sign_in user

    get listings_path

    assert_response :success
    assert_select "a[href='#{scraping_runs_path}']", text: "Runs"
  end

  private

  def create_user!(email:)
    User.create!(
      first_name: "Test",
      last_name: "User",
      email: email,
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
