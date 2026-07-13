class ListingMatchScore
  Result = Data.define(:score, :explanations)

  PRICE_WEIGHT = 60
  BEDROOM_WEIGHT = 25
  DETAIL_FIELDS = %i[price_cents square_meters expenses_cents parking_spaces property_type].freeze

  def initialize(listing, search_preference)
    @listing = listing
    @search_preference = search_preference
  end

  def result
    Result.new(
      score: (price_points + bedroom_points + detail_points).clamp(0, 100),
      explanations: [price_explanation, bedroom_explanation, detail_explanation]
    )
  end

  private

  attr_reader :listing, :search_preference

  def price_points
    return 30 unless search_preference.max_price_cents.present?
    return 0 unless listing.price_cents.present?
    return 0 if price_currency_mismatch?

    ratio = listing.price_cents.fdiv(search_preference.max_price_cents)
    return PRICE_WEIGHT if ratio <= 0.75

    (PRICE_WEIGHT * (1 - ratio) / 0.25).round.clamp(0, PRICE_WEIGHT)
  end

  def bedroom_points
    return 12 unless search_preference.min_bedrooms.present?
    return 0 unless listing.bedrooms.present?

    (20 + ((listing.bedrooms - search_preference.min_bedrooms) * 5)).clamp(0, BEDROOM_WEIGHT)
  end

  def detail_points
    DETAIL_FIELDS.count { |field| listing.public_send(field).present? || listing.public_send(field) == 0 } * 3
  end

  def price_explanation
    return I18n.t("scoring.no_maximum_budget") unless search_preference.max_price_cents.present?
    return I18n.t("scoring.price_unavailable") unless listing.price_cents.present?
    return I18n.t("scoring.price_currency_mismatch") if price_currency_mismatch?

    percent = (((search_preference.max_price_cents - listing.price_cents).fdiv(search_preference.max_price_cents)) * 100).round
    percent.negative? ? I18n.t("scoring.over_budget", percent: percent.abs) : I18n.t("scoring.under_budget", percent: percent)
  end

  def bedroom_explanation
    return I18n.t("scoring.any_bedroom_count") unless search_preference.min_bedrooms.present?
    return I18n.t("scoring.bedrooms_unavailable") unless listing.bedrooms.present?

    I18n.t("scoring.bedroom", count: listing.bedrooms)
  end

  def detail_explanation
    known_fields = detail_points / 3
    return I18n.t("scoring.complete_details") if known_fields == DETAIL_FIELDS.length
    return I18n.t("scoring.good_detail_coverage") if known_fields >= 3

    I18n.t("scoring.basic_details")
  end

  def price_currency_mismatch?
    listing.currency.present? && search_preference.price_currency.present? && listing.currency != search_preference.price_currency
  end
end
