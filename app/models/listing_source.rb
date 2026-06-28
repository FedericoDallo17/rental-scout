class ListingSource < ApplicationRecord
  has_many :listings, dependent: :restrict_with_exception
  has_many :notification_events, dependent: :restrict_with_exception
  has_many :scraping_source_runs, dependent: :restrict_with_exception
  has_many :seen_listings, dependent: :restrict_with_exception

  validates :name, :adapter_key, presence: true
  validates :adapter_key, uniqueness: true
end
