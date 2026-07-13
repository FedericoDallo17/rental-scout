class ListingMatchScore
  Result = Data.define(:score, :explanations, :completeness)

  PRICE_WEIGHT = 70
  BEDROOM_WEIGHT = 30
  DETAIL_FIELDS = %i[price_cents square_meters expenses_cents parking_spaces property_type].freeze

  def initialize(listing, search_preference)
    @listing = listing
    @search_preference = search_preference
  end

  def result
    Result.new(
      score: preference_score,
      explanations: preference_explanations,
      completeness: completeness_label
    )
  end

  private

  attr_reader :listing, :search_preference

  def preference_score
    components = []
    components << [price_fit, PRICE_WEIGHT] if search_preference.max_price_cents.present?
    components << [bedroom_fit, BEDROOM_WEIGHT] if search_preference.min_bedrooms.present?
    return if components.empty?

    weighted_total = components.sum { |fit, weight| fit * weight }
    total_weight = components.sum(&:last)
    (weighted_total.fdiv(total_weight)).round.clamp(0, 100)
  end

  def preference_explanations
    explanations = []
    explanations << price_explanation if search_preference.max_price_cents.present?
    explanations << bedroom_explanation if search_preference.min_bedrooms.present?
    explanations
  end

  def price_fit
    return 0 unless listing.price_cents.present?
    return 0 if price_currency_mismatch?

    ratio = listing.price_cents.fdiv(search_preference.max_price_cents)
    return 100 if ratio <= 0.75

    (100 * (1 - ratio) / 0.25).round.clamp(0, 100)
  end

  def bedroom_fit
    return 0 unless listing.bedrooms.present?

    (80 + ((listing.bedrooms - search_preference.min_bedrooms) * 20)).clamp(0, 100)
  end

  def price_explanation
    return I18n.t("scoring.price_unavailable") unless listing.price_cents.present?
    return I18n.t("scoring.price_currency_mismatch") if price_currency_mismatch?

    percent = (((search_preference.max_price_cents - listing.price_cents).fdiv(search_preference.max_price_cents)) * 100).round
    percent.negative? ? I18n.t("scoring.over_budget", percent: percent.abs) : I18n.t("scoring.under_budget", percent: percent)
  end

  def bedroom_explanation
    return I18n.t("scoring.bedrooms_unavailable") unless listing.bedrooms.present?

    I18n.t("scoring.bedroom", count: listing.bedrooms)
  end

  def completeness_label
    known_fields = DETAIL_FIELDS.count { |field| listing.public_send(field).present? || listing.public_send(field) == 0 }
    return I18n.t("scoring.complete_details") if known_fields == DETAIL_FIELDS.length
    return I18n.t("scoring.good_detail_coverage") if known_fields >= 3

    I18n.t("scoring.basic_details")
  end

  def price_currency_mismatch?
    listing.currency.present? && search_preference.price_currency.present? && listing.currency != search_preference.price_currency
  end
end
