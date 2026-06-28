class ListingsController < ApplicationController
  def index
    @listings = Listing.includes(:listing_source).order(created_at: :desc)
  end
end
