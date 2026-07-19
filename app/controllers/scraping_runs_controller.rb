class ScrapingRunsController < ApplicationController
  def index
    @location_quality = Scraping::LocationQualityMetrics.new.call
    events = NotificationEvent
      .joins(:search_preference, :listing)
      .where(search_preferences: { user_id: current_user.id })
      .where.not(listings: { scraping_run_id: nil })
      .includes(:listing)
    @events_by_run_id = events.group_by { |event| event.listing.scraping_run_id }
    @matched_runs = ScrapingRun.where(id: @events_by_run_id.keys).order(started_at: :desc, id: :desc)

    render "scraping_runs/user_index"
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
