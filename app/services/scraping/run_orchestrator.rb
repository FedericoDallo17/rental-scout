module Scraping
  class RunOrchestrator
    def call(reconciliation: false)
      run = ScrapingRun.create!(status: "running", started_at: Time.current)
      intake = ListingIntake.new

      ListingSource.where(active: true).find_each do |listing_source|
        process_source(run:, listing_source:, intake:, reconciliation:)
      end

      run.update!(
        status: run.scraping_source_runs.exists?(status: "failed") ? "completed_with_failures" : "succeeded",
        finished_at: Time.current
      )
      run
    rescue StandardError => error
      run&.update!(status: "failed", finished_at: Time.current, error_message: error.message)
      raise
    end

    private

    def process_source(run:, listing_source:, intake:, reconciliation:)
      source_run = run.scraping_source_runs.create!(
        listing_source:,
        status: "running",
        started_at: Time.current
      )
      known_external_ids = listing_source.seen_listings.where.not(external_id: nil).pluck(:external_id).to_set
      listings = Sources::AdapterRegistry.resolve(listing_source).fetch_listings(
        known_external_ids:,
        reconciliation:
      )
      created_count = 0

      listings.each do |attributes|
        listing = intake.call(listing_source:, attributes:, scraping_run: run)
        created_count += 1 if listing.instance_variable_get(:@created_by_intake)
      end

      source_run.update!(
        status: "succeeded",
        finished_at: Time.current,
        listings_seen_count: listings.size,
        listings_created_count: created_count
      )

      run.increment!(:listings_seen_count, listings.size)
      run.increment!(:listings_created_count, created_count)
    rescue StandardError => error
      source_run&.update!(status: "failed", finished_at: Time.current, error_message: error.message)
    end
  end
end
