class User < ApplicationRecord
  SUPPORTED_LOCALES = %w[en es].freeze
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :search_preferences, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }

  def pushover_active?
    pushover_enabled? && pushover_user_key.present?
  end
end
