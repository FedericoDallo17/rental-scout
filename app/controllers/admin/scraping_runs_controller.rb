module Admin
  class ScrapingRunsController < BaseController
    def index
      @listing_sources = ListingSource.order(:name)
      @total_third_party_calls = @listing_sources.sum(&:third_party_calls_count)
      @location_quality = Scraping::LocationQualityMetrics.new.call
      @scraping_runs = ScrapingRun
        .includes(scraping_source_runs: :listing_source)
        .order(started_at: :desc, id: :desc)
        .limit(25)
      @active_run = @scraping_runs.find { |run| run.status.in?(%w[running queued]) }

      render "scraping_runs/index"
    end

    def show
      @scraping_run = ScrapingRun
        .includes(scraping_source_runs: :listing_source)
        .find(params[:id])
    end
  end
end
