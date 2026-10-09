module Listings
  class CriteriaFilter
    def initialize(scope, currency: nil, min_price_cents: nil, max_price_cents: nil, min_bedrooms: nil, include_expenses: false, min_square_meters: nil, max_square_meters: nil, include_unknown_area: false)
      @scope = scope
      @currency = currency
      @min_price_cents = min_price_cents
      @max_price_cents = max_price_cents
      @min_bedrooms = min_bedrooms
      @include_expenses = include_expenses
      @min_square_meters = min_square_meters
      @max_square_meters = max_square_meters
      @include_unknown_area = include_unknown_area
    end

    def call
      relation = scope
      relation = relation.where(currency:) if currency.present?
      relation = apply_price(relation)
      relation = relation.where("bedrooms >= ?", min_bedrooms) if min_bedrooms.present?
      apply_area(relation)
    end

    private

    attr_reader :scope, :currency, :min_price_cents, :max_price_cents, :min_bedrooms, :include_expenses

    def apply_area(relation)
      return relation if @min_square_meters.nil? && @max_square_meters.nil?

      conditions = []
      values = {}
      if @min_square_meters
        conditions << "square_meters >= :min"
        values[:min] = @min_square_meters
      end
      if @max_square_meters
        conditions << "square_meters <= :max"
        values[:max] = @max_square_meters
      end
      predicate = conditions.join(" AND ")
      predicate = "(#{predicate}) OR square_meters IS NULL" if @include_unknown_area
      relation.where(predicate, values)
    end

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
