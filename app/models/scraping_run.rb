class ScrapingRun < ApplicationRecord
  has_many :listings, dependent: :nullify
  has_many :scraping_source_runs, dependent: :destroy
  has_many :seen_listings, dependent: :nullify

  validates :status, :started_at, presence: true
end
