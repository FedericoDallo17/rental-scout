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

  test "status keeps the required section structure" do
    status = Rails.root.join(".ai/STATUS.md").read

    [
      "# Status",
      "## Current Phase",
      "## Current Task",
      "## Status",
      "## Done",
      "## Doing",
      "## Blockers",
      "## Risks",
      "## Human Input Needed",
      "## Next Step"
    ].each do |section|
      assert_includes status, "#{section}\n", "expected .ai/STATUS.md to keep a #{section.inspect} section"
    end
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
      assert_includes recurring_config, "  purge_stale_listings:"
      assert_includes recurring_config, "  backfill_info_casas_coordinates:"
    end
    assert_includes recurring_config, "args: [{ limit: 20 }]"
  end

  test "reshape migration backfills source runs from legacy scraping run provenance" do
    migration = Rails.root.join("db/migrate/20260628015000_reshape_scraping_runs.rb").read

    assert_match(/INSERT\s+INTO\s+scraping_source_runs/i, migration)
    assert_match(/listing_source_id/i, migration)
  end

  test "seeds bootstrap listing sources outside production" do
    ListingSource.delete_all

    assert_difference("ListingSource.count", 5) do
      load Rails.root.join("db/seeds.rb")
    end

    assert_equal ["housi", "imperium_inmobiliaria", "info_casas_api", "mock_source", "remax"], ListingSource.order(:adapter_key).pluck(:adapter_key)
    assert_equal(
      {
        "housi" => false,
        "imperium_inmobiliaria" => false,
        "info_casas_api" => true,
        "mock_source" => true,
        "remax" => false
      },
      ListingSource.order(:adapter_key).pluck(:adapter_key, :active).to_h
    )
  end

  test "seeds avoid registering the mock source in production" do
    seeds = Rails.root.join("db/seeds.rb").read

    assert_match(/unless\s+Rails\.env\.production\?/, seeds)
  end

  test "seeds correct zone backed demo saved searches on repeated runs" do
    demo_user = User.find_or_create_by!(email: "demo@example.com") do |user|
      user.first_name = "Demo"
      user.last_name = "User"
      user.password = "password123"
      user.password_confirmation = "password123"
    end
    search = demo_user.search_preferences.find_or_initialize_by(name: "Pocitos")
    search.location_query = "Wrong"
    search.save!

    load Rails.root.join("db/seeds.rb")

    seeded_search = demo_user.search_preferences.find_by!(name: "Pocitos")
    assert_equal "Pocitos", seeded_search.location_query
    assert_equal ["Pocitos"], seeded_search.zones.pluck(:name)
    assert_includes Zone.order(:name).pluck(:name), "Buceo"
    assert_includes Zone.order(:name).pluck(:name), "Cordón"
    assert_includes Zone.order(:name).pluck(:name), "Malvín"
    assert_operator Zone.count, :>=, 12
    assert_equal ["Carrasco", "Centro", "Costa Este", "Pocitos"], demo_user.search_preferences.order(:name).pluck(:name)
  end
end
