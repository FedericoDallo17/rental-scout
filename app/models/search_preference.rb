class SearchPreference < ApplicationRecord
  PRICE_CURRENCIES = %w[UYU USD].freeze

  belongs_to :user

  has_many :notification_events, dependent: :nullify
  has_many :search_zones, dependent: :destroy
  has_many :zones, through: :search_zones

  validates :name, :location_query, presence: true
  validates :price_currency, inclusion: { in: PRICE_CURRENCIES }
  validates :min_square_meters, :max_square_meters,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :ordered_area_range

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

  def ordered_area_range
    if min_square_meters.present? && max_square_meters.present? && min_square_meters > max_square_meters
      errors.add(:max_square_meters, :greater_than_or_equal_to, count: min_square_meters)
    end
  end

  def cents_to_units(cents)
    return if cents.blank?

    cents / 100
  end

  def units_to_cents(value)
    return if value.blank?

    value.to_i * 100
  end
end
