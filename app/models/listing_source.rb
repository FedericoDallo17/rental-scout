class ListingSource < ApplicationRecord
  DISPLAY_NAMES = {
    "info_casas_api" => "InfoCasas"
  }.freeze

  has_many :listings, dependent: :restrict_with_exception
  has_many :notification_events, dependent: :restrict_with_exception
  has_many :scraping_source_runs, dependent: :restrict_with_exception
  has_many :seen_listings, dependent: :restrict_with_exception

  validates :name, :adapter_key, presence: true
  validates :adapter_key, uniqueness: true

  def display_name
    DISPLAY_NAMES.fetch(adapter_key, name)
  end
end
