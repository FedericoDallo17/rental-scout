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
        apply_authoritative_neighborhood!(attrs)
        attrs[:location_resolution_status] = "spatial"
      elsif attrs[:source_neighborhood].present?
        clear_geometry!(attrs)
        attrs[:location_resolution_status] = "fallback"
      else
        clear_geometry!(attrs)
        attrs[:location_resolution_status] = "unresolved"
      end

      attrs
    end

    private

    def decimal_or_nil(value)
      return if value.blank?

      BigDecimal(value.to_s)
    end

    def clear_geometry!(attrs)
      attrs[:latitude] = nil
      attrs[:longitude] = nil
      attrs[:coordinates] = nil
    end

    def apply_authoritative_neighborhood!(attrs)
      zone = Zone.containing(attrs[:coordinates])
      return unless zone&.source_key == Zones::ImportMontevideoNeighborhoods::SOURCE_KEY

      attrs[:source_neighborhood] = zone.name
    end
  end
end
