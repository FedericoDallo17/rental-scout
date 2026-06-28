class SearchPreference < ApplicationRecord
  has_many :notification_events, dependent: :restrict_with_exception

  validates :name, :location_query, presence: true
end
