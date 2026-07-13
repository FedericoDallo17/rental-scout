class SearchPreference < ApplicationRecord
  PRICE_CURRENCIES = %w[UYU USD].freeze

  belongs_to :user

  has_many :notification_events, dependent: :nullify
  has_many :search_zones, dependent: :destroy
  has_many :zones, through: :search_zones

  validates :name, :location_query, presence: true
  validates :price_currency, inclusion: { in: PRICE_CURRENCIES }

  scope :ordered_for_sidebar, -> { order(:created_at, :id) }

  def min_price
    cents_to_units(min_price_cents)
  end

  def min_price=(value)
    self.min_price_cents = units_to_cents(value)
  end

  def max_price
    cents_to_units(max_price_cents)
  end

  def max_price=(value)
    self.max_price_cents = units_to_cents(value)
  end

  private

  def cents_to_units(cents)
    return if cents.blank?

    cents / 100
  end

  def units_to_cents(value)
    return if value.blank?

    value.to_i * 100
  end
end
