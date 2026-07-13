module Scraping
  class LocationQualityMetrics
    Result = Data.define(:spatial_count, :fallback_count, :unresolved_count, :provider_mismatch_count)

    def call
      Result.new(
        spatial_count: Listing.where(location_resolution_status: "spatial").count,
        fallback_count: Listing.where(location_resolution_status: "fallback").count,
        unresolved_count: Listing.where(location_resolution_status: "unresolved").count,
        provider_mismatch_count: provider_mismatch_count
      )
    end

    private

    def provider_mismatch_count
      Listing
        .joins(<<~SQL.squish)
          INNER JOIN zones authoritative_zones
            ON ST_Intersects(authoritative_zones.geom, listings.coordinates)
        SQL
        .where(location_resolution_status: "spatial")
        .where(authoritative_zones: { source_key: Zones::ImportMontevideoNeighborhoods::SOURCE_KEY })
        .where("NULLIF(listings.raw_payload->>'source_neighborhood', '') IS NOT NULL")
        .where(<<~SQL.squish)
          NOT (
            LOWER(BTRIM(SPLIT_PART(listings.raw_payload->>'source_neighborhood', ',', 1))) =
            ANY(authoritative_zones.aliases)
          )
        SQL
        .distinct
        .count
    end
  end
end
