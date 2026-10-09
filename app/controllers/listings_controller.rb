class ListingsController < ApplicationController
  SORT_OPTIONS = %w[newest price_low price_high total_monthly price_per_m2_low price_per_m2_high fit].freeze
  CURRENCIES = %w[UYU USD].freeze
  COST_BASES = %w[rent total].freeze
  PER_PAGE = 24
  FILTER_PARAMS = %i[sort source_id neighborhood currency cost_basis include_expenses
    min_price max_price min_bedrooms expenses_known min_square_meters max_square_meters
    include_unknown_area max_expenses expenses_currency include_unknown_expenses property_type parking_required].freeze

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
    filtered_scope = apply_filters(base_scope)
    @total_listings = filtered_scope.count
    prepare_pagination

    if @sort == "fit"
      candidates = filtered_scope.includes(:listing_source).to_a
      build_listing_metadata(candidates, match_index:, searches_by_id:)
      @listings = sort_by_fit(candidates).slice((@page - 1) * PER_PAGE, PER_PAGE) || []
    else
      @listings = sort_scope(filtered_scope)
        .includes(:listing_source)
        .offset((@page - 1) * PER_PAGE)
        .limit(PER_PAGE)
        .to_a
      build_listing_metadata(@listings, match_index:, searches_by_id:)
    end

    identities = @listings.to_h { |listing| [listing.id, ListingTrack.identity_for(listing)] }
    tracks_by_identity = current_user.listing_tracks.where(
      source_key: identities.values.map { |identity| identity[:source_key] },
      source_identity: identities.values.map { |identity| identity[:source_identity] }
    ).index_by { |track| [track.source_key, track.source_identity] }
    @listing_tracks = identities.transform_values { |identity| tracks_by_identity[[identity[:source_key], identity[:source_identity]]] }
    @feed_params = params.permit(*FILTER_PARAMS).to_h.symbolize_keys
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
    @min_square_meters = non_negative_integer(params[:min_square_meters])
    @max_square_meters = non_negative_integer(params[:max_square_meters])
    @include_unknown_area = params[:include_unknown_area].nil? || params[:include_unknown_area] == "1"
    @max_expenses = non_negative_integer(params[:max_expenses])
    @expenses_currency = params[:expenses_currency].presence_in(CURRENCIES) || "UYU"
    @include_unknown_expenses = params[:include_unknown_expenses].nil? || params[:include_unknown_expenses] == "1"
    @filter_property_types = base_scope.reorder(nil).where.not(property_type: [nil, ""]).distinct.order(:property_type).pluck(:property_type)
    @selected_property_type = params[:property_type].presence_in(@filter_property_types)
    @parking_filter_available = base_scope.reorder(nil).where.not(parking_spaces: nil).exists?
    @parking_required = @parking_filter_available && params[:parking_required] == "1"
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
      min_square_meters: @min_square_meters,
      max_square_meters: @max_square_meters,
      include_unknown_area: @include_unknown_area,
      include_expenses: @cost_basis == "total"
    ).call
    scope = scope.where.not(expenses_cents: nil) if @expenses_known
    scope = apply_expenses_filter(scope)
    scope = scope.where(property_type: @selected_property_type) if @selected_property_type
    scope = scope.where("parking_spaces > 0") if @parking_required
    scope
  end

  def apply_expenses_filter(scope)
    return scope unless @max_expenses

    predicate = <<~SQL.squish
      COALESCE(NULLIF(expenses_currency, ''), currency) = :expenses_currency
      AND expenses_cents <= :max_expenses_cents
    SQL
    predicate = "(#{predicate}) OR expenses_cents IS NULL" if @include_unknown_expenses
    scope.where(predicate, expenses_currency: @expenses_currency, max_expenses_cents: @max_expenses * 100)
  end

  def non_negative_integer(value)
    return if value.blank?

    integer = Integer(value, exception: false)
    integer if integer && integer >= 0
  end

  def build_listing_metadata(listings, match_index:, searches_by_id:)
    @listing_matches = listings.index_with do |listing|
      match_index.search_ids_by_listing_id.fetch(listing.id, []).filter_map { |search_id| searches_by_id[search_id] }
    end
    @listing_scores = listings.index_with do |listing|
      results = @listing_matches.fetch(listing).map { |search| ListingMatchScore.new(listing, search).result }
      results.max_by { |result| result.score || -1 }
    end
  end

  def sort_scope(scope)
    order = case @sort
    when "price_low"
      "currency ASC NULLS LAST, price_cents ASC NULLS LAST, created_at DESC, id DESC"
    when "price_high"
      "currency ASC NULLS LAST, price_cents DESC NULLS LAST, created_at DESC, id DESC"
    when "total_monthly"
      <<~SQL.squish
        currency ASC NULLS LAST,
        CASE WHEN price_cents IS NOT NULL AND expenses_cents IS NOT NULL
          AND COALESCE(NULLIF(expenses_currency, ''), currency) = currency
          THEN price_cents + expenses_cents END ASC NULLS LAST,
        created_at DESC, id DESC
      SQL
    when "price_per_m2_low"
      "currency ASC NULLS LAST, (price_cents::numeric / NULLIF(square_meters, 0)) ASC NULLS LAST, created_at DESC, id DESC"
    when "price_per_m2_high"
      "currency ASC NULLS LAST, (price_cents::numeric / NULLIF(square_meters, 0)) DESC NULLS LAST, created_at DESC, id DESC"
    else
      "created_at DESC, id DESC"
    end
    scope.order(Arel.sql(order))
  end

  def sort_by_fit(listings)
    listings.sort_by { |listing| [-(@listing_scores.fetch(listing).score || -1), -listing.created_at.to_f, -listing.id] }
  end

  def prepare_pagination
    @total_pages = [(@total_listings.to_f / PER_PAGE).ceil, 1].max
    requested_page = non_negative_integer(params[:page]).to_i
    requested_page = 1 if requested_page < 1
    @page = [requested_page, @total_pages].min
  end
end
