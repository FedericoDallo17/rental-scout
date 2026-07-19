class ListingsController < ApplicationController
  SORT_OPTIONS = %w[newest price_low price_high total_monthly fit].freeze
  CURRENCIES = %w[UYU USD].freeze
  COST_BASES = %w[rent total].freeze

  def index
    @searches = current_user.search_preferences.includes(:zones).ordered_for_sidebar
    @active_search = @searches.find_by(id: params[:search_id]) if params[:search_id].present?
    match_index = Listings::SavedSearchMatches.new(@searches).call
    searches_by_id = @searches.index_by(&:id)

    @search_counts = @searches.index_with do |search|
      match_index.listing_ids_by_search_id.fetch(search.id, []).size
    end
    listing_ids = if @active_search
      match_index.listing_ids_by_search_id.fetch(@active_search.id, [])
    else
      match_index.search_ids_by_listing_id.keys
    end

    base_scope = Listing.where(id: listing_ids)
    prepare_filter_options(base_scope)
    @listings = apply_filters(base_scope.includes(:listing_source)).to_a
    @listing_matches = @listings.index_with do |listing|
      match_index.search_ids_by_listing_id.fetch(listing.id, []).filter_map { |search_id| searches_by_id[search_id] }
    end
    @listing_scores = @listings.index_with { |listing| best_score_for(listing) }
    @listings = sort_listings(@listings)
    @feed_params = params.permit(:sort, :source_id, :neighborhood, :currency, :cost_basis, :include_expenses, :min_price, :max_price, :min_bedrooms, :expenses_known).to_h.symbolize_keys
  end

  private

  def prepare_filter_options(base_scope)
    source_ids = base_scope.reorder(nil).select(:listing_source_id)
    @filter_sources = ListingSource.where(id: source_ids).order(:name).to_a
    @filter_zones = Zone.order(:name).to_a
    @selected_source_id = params[:source_id].to_i if @filter_sources.any? { |source| source.id == params[:source_id].to_i }
    @selected_zone = @filter_zones.find { |zone| [zone.slug, zone.name].include?(params[:neighborhood]) }
    @selected_neighborhood = @selected_zone&.slug
    @selected_currency = params[:currency] if CURRENCIES.include?(params[:currency])
    @cost_basis = params[:include_expenses] == "1" || params[:cost_basis] == "total" ? "total" : "rent"
    @min_price = non_negative_integer(params[:min_price])
    @max_price = non_negative_integer(params[:max_price])
    @min_bedrooms = non_negative_integer(params[:min_bedrooms])
    @expenses_known = params[:expenses_known] == "1"
    @sort = SORT_OPTIONS.include?(params[:sort]) ? params[:sort] : "newest"
  end

  def apply_filters(scope)
    scope = scope.where(listing_source_id: @selected_source_id) if @selected_source_id
    scope = scope.where(id: Listing.matching_zone_ids([@selected_zone])) if @selected_zone
    scope = Listings::CriteriaFilter.new(
      scope,
      currency: @selected_currency,
      min_price_cents: @min_price&.*(100),
      max_price_cents: @max_price&.*(100),
      min_bedrooms: @min_bedrooms,
      include_expenses: @cost_basis == "total"
    ).call
    scope = scope.where.not(expenses_cents: nil) if @expenses_known
    scope
  end

  def non_negative_integer(value)
    return if value.blank?

    integer = Integer(value, exception: false)
    integer if integer && integer >= 0
  end

  def best_score_for(listing)
    results = @listing_matches.fetch(listing).map { |search| ListingMatchScore.new(listing, search).result }
    results.max_by { |result| result.score || -1 }
  end

  def sort_listings(listings)
    listings.sort_by do |listing|
      case @sort
      when "price_low"
        [listing.currency.to_s, listing.price_cents.nil? ? 1 : 0, listing.price_cents || 0, -listing.created_at.to_f]
      when "price_high"
        [listing.currency.to_s, listing.price_cents.nil? ? 1 : 0, -(listing.price_cents || 0), -listing.created_at.to_f]
      when "total_monthly"
        total = known_total_monthly_cost(listing)
        [listing.currency.to_s, total.nil? ? 1 : 0, total || 0, -listing.created_at.to_f]
      when "fit"
        [-(@listing_scores.fetch(listing).score || -1), -listing.created_at.to_f]
      else
        [-listing.created_at.to_f]
      end
    end
  end

  def known_total_monthly_cost(listing)
    return unless listing.price_cents.present? && !listing.expenses_cents.nil?

    expenses_currency = listing.expenses_currency.presence || listing.currency
    return unless expenses_currency == listing.currency

    listing.price_cents + listing.expenses_cents
  end
end
