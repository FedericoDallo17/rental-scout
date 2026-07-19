module Scraping
  class BackfillInfoCasasCoordinates
    BATCH_SIZE = 20
    Result = Struct.new(:listings_seen_count, :listings_updated_count, keyword_init: true)

    def call(limit: nil, external_ids: nil, adapter: nil)
      source = ListingSource.find_by!(adapter_key: "info_casas_api")
      adapter ||= Sources::InfoCasasApiAdapter.new(
        on_request: Sources::ThirdPartyCallTracker.new(listing_source: source)
      )
      geometry_builder = Scraping::ListingGeometryBuilder.new
      seen_count = 0
      updated_count = 0

      relation = source.listings
        .where(coordinates: nil)
        .where.not(location_resolution_status: "unresolved")
      relation = relation.where(external_id: Array(external_ids).map(&:to_s)) if external_ids.present?
      relation = relation.limit(limit) if limit.present?

      relation.find_each(batch_size: BATCH_SIZE) do |listing|
        seen_count += 1
        coordinates = adapter.detail_coordinates_for_url(listing.canonical_url)
        next if coordinates[:latitude].blank? || coordinates[:longitude].blank?

        attrs = geometry_builder.call(
          attributes: {
            latitude: coordinates[:latitude],
            longitude: coordinates[:longitude],
            source_neighborhood: listing.source_neighborhood
          }
        )
        listing.update!(attrs.slice(:latitude, :longitude, :coordinates, :location_resolution_status))
        updated_count += 1
      end

      Result.new(listings_seen_count: seen_count, listings_updated_count: updated_count)
    end
  end
end
