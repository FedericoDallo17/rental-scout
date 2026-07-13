module Listings
  class SavedSearchMatches
    Result = Data.define(:listing_ids_by_search_id, :search_ids_by_listing_id)

    def initialize(searches)
      @searches = searches.to_a
    end

    def call
      listing_ids_by_search_id = searches.to_h { |search| [search.id, []] }
      search_ids_by_listing_id = Hash.new { |hash, listing_id| hash[listing_id] = [] }
      return Result.new(listing_ids_by_search_id:, search_ids_by_listing_id:) if searches.empty?

      preload_zones
      rows.each do |row|
        search_id = row.fetch("search_id").to_i
        listing_id = row.fetch("listing_id").to_i
        listing_ids_by_search_id.fetch(search_id) << listing_id
        search_ids_by_listing_id[listing_id] << search_id
      end

      Result.new(listing_ids_by_search_id:, search_ids_by_listing_id: search_ids_by_listing_id.to_h)
    end

    private

    attr_reader :searches

    def preload_zones
      unloaded = searches.reject { |search| search.association(:zones).loaded? }
      return if unloaded.empty?

      ActiveRecord::Associations::Preloader.new(records: unloaded, associations: :zones).call
    end

    def rows
      sql = searches.map do |search|
        Listing.for_search_feed(search)
          .reorder(nil)
          .select("listings.id AS listing_id, #{search.id.to_i} AS search_id")
          .to_sql
      end.join(" UNION ALL ")

      Listing.connection.select_all(sql)
    end
  end
end
