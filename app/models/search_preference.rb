class SearchPreference < ApplicationRecord
  belongs_to :user

  has_many :notification_events, dependent: :nullify
  has_many :search_zones, dependent: :destroy
  has_many :zones, through: :search_zones

  validates :name, :location_query, presence: true

  scope :ordered_for_sidebar, -> { order(:created_at, :id) }
end
