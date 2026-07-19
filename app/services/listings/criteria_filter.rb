module Listings
  class CriteriaFilter
    def initialize(scope, currency: nil, min_price_cents: nil, max_price_cents: nil, min_bedrooms: nil, include_expenses: false)
      @scope = scope
      @currency = currency
      @min_price_cents = min_price_cents
      @max_price_cents = max_price_cents
      @min_bedrooms = min_bedrooms
      @include_expenses = include_expenses
    end

    def call
      relation = scope
      relation = relation.where(currency:) if currency.present?
      relation = apply_price(relation)
      relation = relation.where("bedrooms >= ?", min_bedrooms) if min_bedrooms.present?
      relation
    end

    private

    attr_reader :scope, :currency, :min_price_cents, :max_price_cents, :min_bedrooms, :include_expenses

    def apply_price(relation)
      return relation if min_price_cents.blank? && max_price_cents.blank?

      if include_expenses
        relation = relation
          .where.not(price_cents: nil, expenses_cents: nil)
          .where("COALESCE(NULLIF(expenses_currency, ''), currency) = currency")
        expression = "price_cents + expenses_cents"
      else
        relation = relation.where.not(price_cents: nil)
        expression = "price_cents"
      end

      relation = relation.where("#{expression} >= ?", min_price_cents) if min_price_cents.present?
      relation = relation.where("#{expression} <= ?", max_price_cents) if max_price_cents.present?
      relation
    end
  end
end
