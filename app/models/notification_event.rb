class NotificationEvent < ApplicationRecord
  belongs_to :listing
  belongs_to :listing_source
  belongs_to :search_preference, optional: true

  validates :event_kind, :idempotency_key, :status, presence: true
  validates :idempotency_key, uniqueness: true
end
