class ScrapingRunsController < ApplicationController
  def index
    @scraping_runs = ScrapingRun
      .includes(scraping_source_runs: :listing_source)
      .order(started_at: :desc, id: :desc)
      .limit(25)
  end
end
