module Scraping
  class ListingGeometryBuilder
    def call(attributes:)
      attrs = attributes.dup
      latitude = decimal_or_nil(attrs[:latitude])
      longitude = decimal_or_nil(attrs[:longitude])

      if latitude && longitude
        attrs[:latitude] = latitude
        attrs[:longitude] = longitude
        attrs[:coordinates] = Zone::FACTORY.point(longitude, latitude)
        attrs[:location_resolution_status] = "spatial"
      elsif attrs[:source_neighborhood].present?
        attrs[:coordinates] = nil
        attrs[:location_resolution_status] = "fallback"
      else
        attrs[:coordinates] = nil
        attrs[:location_resolution_status] = "unresolved"
      end

      attrs
    end

    private

    def decimal_or_nil(value)
      return if value.blank?

      BigDecimal(value.to_s)
    end
  end
end
