class ListingsController < ApplicationController
  def index
    @searches = SearchPreference.ordered_for_sidebar
    @active_search = @searches.find_by(id: params[:search_id]) || @searches.first
    @listings = if @active_search
      Listing.includes(:listing_source).for_search_feed(@active_search)
    else
      Listing.none
    end
  end
end
