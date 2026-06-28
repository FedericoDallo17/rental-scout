class Listing < ApplicationRecord
  belongs_to :listing_source
  belongs_to :scraping_run, optional: true

  has_many :notification_events, dependent: :restrict_with_exception
  has_many :seen_listings, dependent: :nullify

  validates :title, :canonical_url, presence: true
  validates :canonical_url, uniqueness: { scope: :listing_source_id }
  validates :external_id, uniqueness: { scope: :listing_source_id }, allow_nil: true

  scope :recent_first, -> { order(created_at: :desc) }

  def self.for_search_feed(search_preference)
    return recent_first unless search_preference

    listings = where("LOWER(location_text) LIKE ?", "%#{sanitize_sql_like(search_preference.location_query.downcase)}%")
    listings = listings.where("price_cents >= ?", search_preference.min_price_cents) if search_preference.min_price_cents.present?
    listings = listings.where("price_cents <= ?", search_preference.max_price_cents) if search_preference.max_price_cents.present?
    listings = listings.where("bedrooms >= ?", search_preference.min_bedrooms) if search_preference.min_bedrooms.present?
    listings.recent_first
  end
end
