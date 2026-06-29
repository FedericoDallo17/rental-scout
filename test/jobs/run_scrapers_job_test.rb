require "test_helper"

module Sources
  class StubSourceAdapter
    def fetch_listings
      [{
        external_id: "stub-1",
        title: "Centro Loft",
        canonical_url: "https://example.test/listings/stub-1",
        location_text: "Centro",
        price_cents: 2100000,
        square_meters: 40
      }]
    end
  end
end

class RunScrapersJobTest < ActiveJob::TestCase
  test "creates a scraping run when performed" do
    assert_difference("ScrapingRun.count", 1) do
      RunScrapersJob.perform_now
    end
  end

  test "links the run to the records it processes" do
    ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")

    run = RunScrapersJob.perform_now

    assert_equal 10, run.listings.count
    assert_equal 10, run.seen_listings.count
    assert_equal run.id, Listing.last.scraping_run_id
    assert_equal run.id, SeenListing.last.scraping_run_id
    assert_predicate Listing.last.description, :present?
  end

  test "creates per-source outcome records for an orchestrated run" do
    ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")

    run = RunScrapersJob.perform_now

    assert_nil run.respond_to?(:listing_source) ? run.listing_source : nil
    assert_equal 1, run.scraping_source_runs.count

    source_run = run.scraping_source_runs.first
    assert_equal "mock_source", source_run.listing_source.adapter_key
    assert_equal "succeeded", source_run.status
    assert_equal 10, source_run.listings_seen_count
    assert_equal 10, source_run.listings_created_count
  end

  test "does not run inactive sources" do
    ListingSource.create!(name: "Mock Source", adapter_key: "mock_source", active: false)

    assert_difference("ScrapingRun.count", 1) do
      assert_no_difference(["Listing.count", "SeenListing.count"]) do
        run = RunScrapersJob.perform_now

        assert_instance_of ScrapingRun, run
        assert_equal "succeeded", run.status
        assert_equal 0, run.listings_seen_count
        assert_equal 0, run.listings_created_count
        assert_equal 0, run.scraping_source_runs.count
      end
    end
  end

  test "resolves adapters from the source adapter key" do
    ListingSource.create!(name: "Stub Source", adapter_key: "stub_source")

    run = RunScrapersJob.perform_now

    assert_equal "stub_source", run.scraping_source_runs.first.listing_source.adapter_key
    assert_equal "Stub Source", Listing.last.listing_source.name
    assert_equal "https://example.test/listings/stub-1", Listing.last.canonical_url
  end

  test "records a failed source run for unsupported adapters and continues" do
    ListingSource.create!(name: "Broken Source", adapter_key: "missing_source")
    ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")

    run = RunScrapersJob.perform_now

    assert_equal "completed_with_failures", run.status
    assert_equal 2, run.scraping_source_runs.count
    assert_equal ["failed", "succeeded"], run.scraping_source_runs.order(:id).pluck(:status)
    assert_equal "uninitialized constant Sources::MissingSourceAdapter", run.scraping_source_runs.order(:id).first.error_message
    assert_equal 10, run.listings_seen_count
    assert_equal 10, run.listings_created_count
  end

  test "keeps a succeeded run status when all source runs succeed" do
    ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")

    run = RunScrapersJob.perform_now

    assert_equal "succeeded", run.status
  end
end
