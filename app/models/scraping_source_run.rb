class ScrapingSourceRun < ApplicationRecord
  belongs_to :listing_source
  belongs_to :scraping_run

  validates :status, :started_at, presence: true
end
