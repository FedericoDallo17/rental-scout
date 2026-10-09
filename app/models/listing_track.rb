class ListingTrack < ApplicationRecord
  DATE_FIELDS = %w[contacted_on visited_on rejected_on].freeze
  SNAPSHOT_FIELDS = %w[title canonical_url price_cents currency expenses_cents expenses_currency bedrooms square_meters parking_spaces].freeze

  belongs_to :user
  belongs_to :listing, optional: true

  validates :source_key, :source_identity, :snapshot, presence: true
  validates :source_identity, uniqueness: { scope: [:user_id, :source_key] }
  validate :valid_history_dates

  scope :with_history, -> { where("favorite OR contacted_on IS NOT NULL OR visited_on IS NOT NULL OR rejected_on IS NOT NULL") }

  def self.identity_for(listing)
    {
      source_key: listing.listing_source.adapter_key,
      source_identity: listing.external_id.present? ? "id:#{listing.external_id}" : "url:#{listing.canonical_url}"
    }
  end

  def capture_listing(listing)
    self.listing = listing
    assign_attributes(self.class.identity_for(listing))
    self.snapshot = listing.attributes.slice(*SNAPSHOT_FIELDS).merge(
      "location" => listing.display_location,
      "source_name" => listing.listing_source.display_name
    )
  end

  private

  def valid_history_dates
    DATE_FIELDS.each do |field|
      raw = public_send("#{field}_before_type_cast")
      errors.add(field, :invalid) if raw.present? && public_send(field).nil?
    end
  end
end
