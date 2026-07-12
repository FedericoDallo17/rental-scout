class ListingsController < ApplicationController
  def index
    @searches = current_user.search_preferences.includes(:zones).ordered_for_sidebar
    @active_search = @searches.find_by(id: params[:search_id]) || @searches.first
    @search_counts = @searches.index_with { |search| Listing.for_search_feed(search).count }
    @listings = if @active_search
      Listing.includes(:listing_source).for_search_feed(@active_search)
    else
      Listing.none
    end
    @listing_scores = @listings.index_with { |listing| ListingMatchScore.new(listing, @active_search).result }
    @listings = @listings.sort_by { |listing| [-@listing_scores.fetch(listing).score, -listing.created_at.to_f] }
  end
end
