class ScrapingRunsController < ApplicationController
  def index
    @listing_sources = ListingSource.order(:name)
    @location_quality = Scraping::LocationQualityMetrics.new.call
    @scraping_runs = ScrapingRun
      .includes(scraping_source_runs: :listing_source)
      .order(started_at: :desc, id: :desc)
      .limit(25)
  end

  def show
    @scraping_run = ScrapingRun.find(params[:id])
    @events = NotificationEvent
      .joins(:listing, :search_preference)
      .where(listings: { scraping_run_id: @scraping_run.id })
      .where(search_preferences: { user_id: current_user.id })
      .includes(:search_preference, listing: :listing_source)
      .order("listings.created_at DESC", "notification_events.id ASC")
    @matches = @events.group_by(&:listing)
  end
end
