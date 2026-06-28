class Listing < ApplicationRecord
  belongs_to :listing_source
  belongs_to :scraping_run, optional: true

  has_many :notification_events, dependent: :restrict_with_exception
  has_many :seen_listings, dependent: :nullify

  validates :title, :canonical_url, presence: true
  validates :canonical_url, uniqueness: { scope: :listing_source_id }
  validates :external_id, uniqueness: { scope: :listing_source_id }, allow_nil: true
end
