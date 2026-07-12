class ScrapingRunsController < ApplicationController
  def index
    @listing_sources = ListingSource.order(:name)
    @scraping_runs = ScrapingRun
      .includes(scraping_source_runs: :listing_source)
      .order(started_at: :desc, id: :desc)
      .limit(25)
  end
end
