class Listing < ApplicationRecord
  belongs_to :listing_source
  belongs_to :scraping_run, optional: true

  has_many :notification_events, dependent: :restrict_with_exception
  has_many :seen_listings, dependent: :nullify
  has_many :listing_tracks, dependent: :nullify

  validates :title, :canonical_url, presence: true
  validates :canonical_url, uniqueness: { scope: :listing_source_id }
  validates :external_id, uniqueness: { scope: :listing_source_id }, allow_nil: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :in_scope_inventory, -> { where(in_scope: true) }
  scope :spatially_resolvable, -> { where.not(coordinates: nil) }
  scope :fallback_only, -> { where(location_resolution_status: "fallback") }
  scope :unresolved_location, -> { where(location_resolution_status: "unresolved") }

  def display_location
    neighborhood = provider_neighborhood.presence || source_neighborhood
    return location_text if neighborhood.blank?

    city = raw_payload_value("source_city")
    [neighborhood, city].compact_blank.uniq.join(", ")
  end

  def provider_neighborhood
    raw_payload_value("source_neighborhood").to_s.split(",").first&.strip
  end

  def price_per_square_meter_cents
    return unless price_cents.present? && square_meters.to_i.positive?

    price_cents / square_meters
  end

  private

  def raw_payload_value(key)
    raw_payload&.[](key) || raw_payload&.[](key.to_sym)
  end

  def self.for_search_feed(search_preference)
    return recent_first unless search_preference

    listings = in_scope_inventory
    listings = listings.where(operation_type: search_preference.operation_type)
    listings = if search_has_zones?(search_preference)
      listings.where(id: matching_zone_ids(search_preference.zones.to_a))
    else
      listings.where("LOWER(location_text) LIKE ?", "%#{sanitize_sql_like(search_preference.location_query.to_s.downcase)}%")
    end
    listings = Listings::CriteriaFilter.new(
      listings,
      currency: (search_preference.price_currency if search_preference.min_price_cents.present? || search_preference.max_price_cents.present?),
      min_price_cents: search_preference.min_price_cents,
      max_price_cents: search_preference.max_price_cents,
      min_bedrooms: search_preference.min_bedrooms,
      min_square_meters: search_preference.min_square_meters,
      max_square_meters: search_preference.max_square_meters,
      include_expenses: search_preference.include_expenses?
    ).call
    listings.recent_first
  end

  def self.search_has_zones?(search_preference)
    association = search_preference.association(:zones)
    association.loaded? ? association.target.any? : association.scope.exists?
  end

  def self.matching_zone_ids(zones)
    zone_ids = zones.map(&:id)
    aliases = zones.flat_map { |zone| zone.aliases + [zone.name] }.map(&:downcase).uniq

    spatial_ids = joins("INNER JOIN zones feed_zones ON ST_Intersects(feed_zones.geom, listings.coordinates)")
      .where(location_resolution_status: "spatial")
      .where("feed_zones.id IN (?)", zone_ids)
      .select(:id)

    fallback_ids = fallback_only
      .where("LOWER(source_neighborhood) IN (?)", aliases)
      .select(:id)

    where(id: spatial_ids).or(where(id: fallback_ids)).select(:id)
  end
end
