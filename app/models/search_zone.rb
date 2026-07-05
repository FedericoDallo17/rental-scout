class SearchZone < ApplicationRecord
  belongs_to :search_preference
  belongs_to :zone

  validates :zone_id, uniqueness: { scope: :search_preference_id }
end
