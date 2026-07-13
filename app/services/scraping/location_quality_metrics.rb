module Scraping
  class LocationQualityMetrics
    SourceResult = Data.define(:source_id, :source_name, :total_count, :spatial_count, :fallback_count, :unresolved_count) do
      def coverage_percentage
        return 0 if total_count.zero?

        (spatial_count * 100.0 / total_count).round
      end
    end
    Result = Data.define(:spatial_count, :fallback_count, :unresolved_count, :provider_mismatch_count, :by_source)

    def call
      Result.new(
        spatial_count: Listing.where(location_resolution_status: "spatial").count,
        fallback_count: Listing.where(location_resolution_status: "fallback").count,
        unresolved_count: Listing.where(location_resolution_status: "unresolved").count,
        provider_mismatch_count: provider_mismatch_count,
        by_source: by_source
      )
    end

    private

    def by_source
      counts = Listing.group(:listing_source_id, :location_resolution_status).count

      ListingSource.order(:name).map do |source|
        statuses = counts.each_with_object({}) do |((source_id, status), count), result|
          result[status] = count if source_id == source.id
        end
        total = statuses.values.sum
        SourceResult.new(
          source_id: source.id,
          source_name: source.display_name,
          total_count: total,
          spatial_count: statuses.fetch("spatial", 0),
          fallback_count: statuses.fetch("fallback", 0),
          unresolved_count: statuses.fetch("unresolved", 0)
        )
      end
    end

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
