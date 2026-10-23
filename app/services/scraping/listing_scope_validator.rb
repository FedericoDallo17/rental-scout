module Scraping
  class ListingScopeValidator
    MONTEVIDEO_NAMES = ["montevideo"].freeze
    OPERATION_NAMES = %w[alquiler venta].freeze

    def call(attributes:)
      attrs = attributes.dup
      city = attrs[:source_city].to_s.downcase
      operation = attrs[:operation_type].to_s.downcase

      attrs[:in_scope] = MONTEVIDEO_NAMES.include?(city) && OPERATION_NAMES.include?(operation)
      attrs[:scope_rejection_reason] = attrs[:in_scope] ? nil : rejection_reason(city:, operation:)
      attrs
    end

    private

    def rejection_reason(city:, operation:)
      return "outside_montevideo" unless MONTEVIDEO_NAMES.include?(city)
      return "unknown_operation" unless OPERATION_NAMES.include?(operation)

      "unknown_scope_failure"
    end
  end
end
