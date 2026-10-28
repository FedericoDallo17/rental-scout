class User < ApplicationRecord
  SUPPORTED_LOCALES = %w[en es].freeze
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :search_preferences, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :listing_tracks, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }

  def pushover_active?
    pushover_enabled? && pushover_user_key.present?
  end

  # Recovery is requested while signed out; the request language may differ
  # from the account's saved language.
  def send_devise_notification(notification, *args)
    I18n.with_locale(locale) { super }
  end
end
