class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh, :auth, presence: true
  validates :endpoint, uniqueness: true
  validate :endpoint_uses_https

  private

  def endpoint_uses_https
    uri = URI.parse(endpoint.to_s)
    errors.add(:endpoint, "must use HTTPS") unless uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    errors.add(:endpoint, "is invalid")
  end
end
