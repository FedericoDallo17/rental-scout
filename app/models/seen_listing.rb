class SeenListing < ApplicationRecord
  belongs_to :listing_source
  belongs_to :listing, optional: true
  belongs_to :scraping_run, optional: true

  validates :canonical_url, presence: true
  validates :canonical_url, uniqueness: { scope: :listing_source_id }
  validates :external_id, uniqueness: { scope: :listing_source_id }, allow_nil: true
end
