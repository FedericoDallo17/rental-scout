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
    return "No maximum budget" unless search_preference.max_price_cents.present?
    return "Price unavailable" unless listing.price_cents.present?

    percent = (((search_preference.max_price_cents - listing.price_cents).fdiv(search_preference.max_price_cents)) * 100).round
    percent.negative? ? "#{percent.abs}% over budget" : "#{percent}% under budget"
  end

  def bedroom_explanation
    return "Any bedroom count" unless search_preference.min_bedrooms.present?
    return "Bedrooms unavailable" unless listing.bedrooms.present?

    "#{listing.bedrooms} #{'bedroom'.pluralize(listing.bedrooms)}"
  end

  def detail_explanation
    known_fields = detail_points / 3
    return "Complete details" if known_fields == DETAIL_FIELDS.length
    return "Good detail coverage" if known_fields >= 3

    "Basic details"
  end
end
