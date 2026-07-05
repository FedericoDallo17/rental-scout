class SearchPreference < ApplicationRecord
  belongs_to :user

  has_many :notification_events, dependent: :restrict_with_exception
  has_many :search_zones, dependent: :destroy
  has_many :zones, through: :search_zones

  validates :name, :location_query, presence: true
  validate :must_have_at_least_one_zone

  scope :ordered_for_sidebar, -> { order(:created_at, :id) }

  private

  def must_have_at_least_one_zone
    active_search_zones = search_zones.reject(&:marked_for_destruction?)

    errors.add(:zones, "must include at least one zone") if active_search_zones.empty?
  end
end
