require "test_helper"

class Admin::MaintenanceControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "admin can queue each maintenance job" do
    sign_in create_admin!

    assert_enqueued_with(job: RunScrapersJob, args: []) do
      post admin_maintenance_path, params: { maintenance: { operation: "scrape" } }
    end
    assert_redirected_to admin_root_path

    assert_enqueued_with(job: RunScrapersJob, args: [{ reconciliation: true }]) do
      post admin_maintenance_path, params: { maintenance: { operation: "reconcile" } }
    end
    assert_enqueued_with(job: BackfillInfoCasasCoordinatesJob) do
      post admin_maintenance_path, params: { maintenance: { operation: "backfill_coordinates" } }
    end
    assert_enqueued_with(job: PurgeStaleListingsJob) do
      post admin_maintenance_path, params: { maintenance: { operation: "purge" } }
    end
  end

  test "does not queue another scrape while a run is active" do
    sign_in create_admin!
    run = ScrapingRun.create!(status: "running", started_at: Time.current)

    assert_no_enqueued_jobs do
      post admin_maintenance_path, params: { maintenance: { operation: "scrape" } }
    end

    assert_redirected_to admin_scraping_run_path(run)
  end

  test "closes an abandoned run and queues a new scrape" do
    sign_in create_admin!
    stale_run = ScrapingRun.create!(status: "running", started_at: 3.hours.ago)

    assert_enqueued_with(job: RunScrapersJob) do
      post admin_maintenance_path, params: { maintenance: { operation: "scrape" } }
    end

    assert_redirected_to admin_root_path
    assert_equal "failed", stale_run.reload.status
    assert_predicate stale_run.finished_at, :present?
    assert_match(/maximum run time/, stale_run.error_message)
  end

  test "normal user cannot queue maintenance" do
    user = create_admin!(email: "normal-maintenance@example.com", admin: false)
    sign_in user

    assert_no_enqueued_jobs do
      post admin_maintenance_path, params: { maintenance: { operation: "purge" } }
    end
    assert_response :not_found
  end

  test "unknown maintenance action is not found" do
    sign_in create_admin!

    assert_no_enqueued_jobs do
      post admin_maintenance_path, params: { maintenance: { operation: "unknown" } }
    end
    assert_response :not_found
  end

  private

  def create_admin!(email: "maintenance-admin@example.com", admin: true)
    User.create!(
      first_name: "Maintenance",
      last_name: "Admin",
      email:,
      password: "password123",
      password_confirmation: "password123",
      admin:
    )
  end
end
