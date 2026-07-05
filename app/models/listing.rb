class Listing < ApplicationRecord
  belongs_to :listing_source
  belongs_to :scraping_run, optional: true

  has_many :notification_events, dependent: :restrict_with_exception
  has_many :seen_listings, dependent: :nullify

  validates :title, :canonical_url, presence: true
  validates :canonical_url, uniqueness: { scope: :listing_source_id }
  validates :external_id, uniqueness: { scope: :listing_source_id }, allow_nil: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :in_scope_inventory, -> { where(in_scope: true) }
  scope :spatially_resolvable, -> { where.not(coordinates: nil) }
  scope :fallback_only, -> { where(location_resolution_status: "fallback") }
  scope :unresolved_location, -> { where(location_resolution_status: "unresolved") }

  def self.for_search_feed(search_preference)
    return recent_first unless search_preference

    listings = in_scope_inventory
    listings = if search_preference.zones.exists?
      listings.where(id: zone_matching_ids(search_preference))
    else
      listings.where("LOWER(location_text) LIKE ?", "%#{sanitize_sql_like(search_preference.location_query.to_s.downcase)}%")
    end
    listings = listings.where("price_cents >= ?", search_preference.min_price_cents) if search_preference.min_price_cents.present?
    listings = listings.where("price_cents <= ?", search_preference.max_price_cents) if search_preference.max_price_cents.present?
    listings = listings.where("bedrooms >= ?", search_preference.min_bedrooms) if search_preference.min_bedrooms.present?
    listings.recent_first
  end

  def self.zone_matching_ids(search_preference)
    zone_ids = search_preference.zone_ids
    aliases = search_preference.zones.flat_map(&:aliases).map(&:downcase).uniq

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
