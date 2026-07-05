module Scraping
  class ListingScopeValidator
    MONTEVIDEO_NAMES = ["montevideo"].freeze
    RENTAL_NAMES = ["alquiler"].freeze

    def call(attributes:)
      attrs = attributes.dup
      city = attrs[:source_city].to_s.downcase
      operation = attrs[:operation_type].to_s.downcase

      attrs[:in_scope] = MONTEVIDEO_NAMES.include?(city) && RENTAL_NAMES.include?(operation)
      attrs[:scope_rejection_reason] = attrs[:in_scope] ? nil : rejection_reason(city:, operation:)
      attrs
    end

    private

    def rejection_reason(city:, operation:)
      return "outside_montevideo" unless MONTEVIDEO_NAMES.include?(city)
      return "not_rental" unless RENTAL_NAMES.include?(operation)

      "unknown_scope_failure"
    end
  end
end
