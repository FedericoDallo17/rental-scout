class ListingSourcesController < ApplicationController
  def update
    listing_source = ListingSource.find(params[:id])
    listing_source.update!(active: active_param)

    redirect_to scraping_runs_path
  end

  private

  def active_param
    ActiveModel::Type::Boolean.new.cast(params.require(:listing_source).fetch(:active))
  end
end
