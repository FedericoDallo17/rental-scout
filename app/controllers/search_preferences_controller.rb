class SearchPreferencesController < ApplicationController
  before_action :set_search_preference, only: [:edit, :update, :destroy]
  before_action :set_zones, only: [:new, :create, :edit, :update]

  def new
    @search_preference = current_user.search_preferences.build(notifications_enabled: true)
  end

  def create
    @search_preference = current_user.search_preferences.build(search_preference_params)

    if @search_preference.save
      redirect_to listings_path(search_id: @search_preference.id), notice: t("flash.search_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @search_preference.update(search_preference_params)
      redirect_to listings_path(search_id: @search_preference.id), notice: t("flash.search_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @search_preference.destroy!
    redirect_to listings_path, notice: t("flash.search_deleted")
  end

  private

  def set_search_preference
    @search_preference = current_user.search_preferences.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def set_zones
    @zones = Zone.order(:name)
  end

  def search_preference_params
    params.require(:search_preference).permit(
      :name,
      :location_query,
      :operation_type,
      :min_price,
      :max_price,
      :price_currency,
      :min_bedrooms,
      :min_square_meters,
      :max_square_meters,
      :include_expenses,
      :notifications_enabled,
      zone_ids: []
    )
  end
end
