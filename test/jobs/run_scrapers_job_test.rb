require "test_helper"

module Sources
  class StubSourceAdapter
    def fetch_listings
      [{
        external_id: "stub-1",
        title: "Centro Loft",
        canonical_url: "https://example.test/listings/stub-1",
        location_text: "Centro",
        source_city: "Montevideo",
        operation_type: "alquiler",
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

  test "enqueues notification fan-out after run" do
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    begin
      assert_enqueued_with(job: NotifyNewListingsJob) do
        RunScrapersJob.perform_now
      end
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
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

  test "ingests listings from the info casas api adapter through the orchestrator" do
    ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")

    adapter = Object.new
    adapter.define_singleton_method(:fetch_listings) do
      [{
        external_id: "123",
        title: "Apartamento en Pocitos",
        canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/pocitos/123",
        description: "Apartamento luminoso con terraza",
        price_cents: 3_500_000,
            currency: "UYU",
            location_text: "Pocitos, Montevideo",
            source_city: "Montevideo",
            operation_type: "alquiler",
            bedrooms: 2,
            square_meters: 58
      }]
    end

    original_new = Sources::InfoCasasApiAdapter.method(:new)

    begin
      Sources::InfoCasasApiAdapter.define_singleton_method(:new) { adapter }
      run = RunScrapersJob.perform_now

      assert_equal "succeeded", run.status
      assert_equal 1, run.listings_seen_count
      assert_equal 1, run.listings_created_count
      assert_equal 1, run.scraping_source_runs.count

      source_run = run.scraping_source_runs.first
      assert_equal "info_casas_api", source_run.listing_source.adapter_key
      assert_equal "succeeded", source_run.status
      assert_equal 1, source_run.listings_seen_count
      assert_equal 1, source_run.listings_created_count

      listing = Listing.last
      assert_equal "123", listing.external_id
      assert_equal "https://www.infocasas.com.uy/alquiler/apartamento/pocitos/123", listing.canonical_url
      assert_equal "Pocitos, Montevideo", listing.location_text
      assert_equal 3_500_000, listing.price_cents
      assert_equal "UYU", listing.currency
      assert_equal "Apartamento luminoso con terraza", listing.description
      assert_equal listing.id, SeenListing.last.listing_id
    ensure
      Sources::InfoCasasApiAdapter.define_singleton_method(:new, original_new)
    end
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
