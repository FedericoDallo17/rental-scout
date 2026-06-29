require "test_helper"

class BootstrapConfigTest < ActiveSupport::TestCase
  test "ai workflow skeleton keeps required docs and trackable empty directories" do
    %w[
      .ai/AGENTS.md
      .ai/GOVERNANCE.md
      .ai/STATUS.md
      .ai/context_packs/.keep
      .ai/decisions/.keep
      .ai/docs/.keep
      .ai/feature_summaries/.keep
      .ai/metrics/.keep
      .ai/product/brief.md
      .ai/product/discovery.md
      .ai/product/look_and_feel.md
      .ai/product/mvp_scope.md
      .ai/product/roadmap.md
      .ai/product/user_flows.md
      .ai/reviews/.keep
      .ai/templates/.keep
      .ai/tickets/.keep
    ].each do |relative_path|
      assert Rails.root.join(relative_path).file?, "expected #{relative_path} to exist"
    end
  end

  test "status matches the scraper domain ADR baseline" do
    status = Rails.root.join(".ai/STATUS.md").read

    assert_equal expected_status_baseline, status
  end

  test "development uses solid queue for active job" do
    environment = Rails.root.join("config/environments/development.rb").read

    assert_includes environment, "config.active_job.queue_adapter = :solid_queue"
  end

  test "test uses solid queue for active job" do
    environment = Rails.root.join("config/environments/test.rb").read

    assert_includes environment, "config.active_job.queue_adapter = :solid_queue"
  end

  test "development defines a queue database for solid queue" do
    database_config = Rails.root.join("config/database.yml").read

    assert_includes database_config, "development:"
    assert_includes database_config, "  queue:"
    assert_includes database_config, "    database: rental_scout_lite_development_queue"
  end

  test "test defines a queue database for solid queue" do
    database_config = Rails.root.join("config/database.yml").read

    assert_includes database_config, "test:"
    assert_includes database_config, "  queue:"
    assert_includes database_config, "    database: rental_scout_lite_test_queue"
  end

  test "recurring config defines the scraper schedule in every Rails environment" do
    recurring_config = Rails.root.join("config/recurring.yml").read

    %w[development test production].each do |environment|
      assert_includes recurring_config, "#{environment}:"
      assert_includes recurring_config, "  run_scrapers:"
    end
  end

  test "reshape migration backfills source runs from legacy scraping run provenance" do
    migration = Rails.root.join("db/migrate/20260628015000_reshape_scraping_runs.rb").read

    assert_match(/INSERT\s+INTO\s+scraping_source_runs/i, migration)
    assert_match(/listing_source_id/i, migration)
  end

  test "seeds bootstrap the mock source outside production" do
    ListingSource.delete_all

    assert_difference("ListingSource.count", 1) do
      load Rails.root.join("db/seeds.rb")
    end

    assert_equal "mock_source", ListingSource.last.adapter_key
  end

  test "seeds avoid registering the mock source in production" do
    seeds = Rails.root.join("db/seeds.rb").read

    assert_match(/unless\s+Rails\.env\.production\?/, seeds)
  end

  test "seeds correct demo saved search locations on repeated runs" do
    SearchPreference.create!(name: "Pocitos", location_query: "Wrong")

    load Rails.root.join("db/seeds.rb")

    assert_equal "Pocitos", SearchPreference.find_by!(name: "Pocitos").location_query
  end

  private

  def expected_status_baseline
    <<~MARKDOWN
      # Status

      ## Current Phase
      Bootstrap complete

      ## Current Task
      Awaiting next scraper implementation ticket

      ## Status
      Done

      ## Done
      - Docs and tickets created
      - Rails app initialized
      - Core models added
      - Mock scraper pipeline added
      - Initial portal added
      - Scraper domain ADR defined

      ## Doing
      - None

      ## Blockers
      - None

      ## Risks
      - Real source adapters and notification delivery still require careful escalation

      ## Human Input Needed
      - Choose next implementation ticket

      ## Next Step
      Execute Ticket 008 or 009 using the scraper domain ADR as the baseline
    MARKDOWN
  end
end
