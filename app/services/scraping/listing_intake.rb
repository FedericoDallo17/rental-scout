module Scraping
 class ListingIntake
 class InvalidAttributesError < StandardError; end

 REQUIRED_ATTRIBUTES = %i[title canonical_url source_city operation_type].freeze

 def call(listing_source:, attributes:, scraping_run: nil)
 validate_attributes!(attributes)
 listing, was_new_record = persist_listing(listing_source:, attributes:, scraping_run:)

      upsert_seen_listing(listing_source:, listing:, attributes:, scraping_run:)

      listing.instance_variable_set(:@created_by_intake, was_new_record)
      listing
    end

 private

 def validate_attributes!(attributes)
 missing = REQUIRED_ATTRIBUTES.select { |key| attributes[key].blank? }
 return if missing.empty?

 raise InvalidAttributesError,
 "missing required attributes: #{missing.join(', ')} (canonical_url=#{attributes[:canonical_url].inspect})"
 end

 def listing_attributes(attributes)
      attrs = Scraping::ListingGeometryBuilder.new.call(attributes: attributes.dup)
      attrs = Scraping::ListingScopeValidator.new.call(attributes: attrs)
      attrs = attrs.slice(*Listing.attribute_names.map(&:to_sym))
      attrs[:raw_payload] = attributes
      attrs
    end

    def find_listing(listing_source:, attributes:)
      by_external_id = listing_source.listings.find_by(external_id: attributes[:external_id]) if attributes[:external_id].present?
      return by_external_id if by_external_id

      listing_source.listings.find_by(canonical_url: attributes[:canonical_url])
    end

    def persist_listing(listing_source:, attributes:, scraping_run:)
      listing = find_listing(listing_source:, attributes:)
      cross_source_listing = find_cross_source_listing(listing_source:, attributes:) unless listing
      return [ cross_source_listing, false ] if cross_source_listing

      listing ||= Listing.new(listing_source:)
      was_new_record = listing.new_record?
      listing.assign_attributes(listing_attributes(attributes))
      listing.scraping_run = scraping_run if scraping_run && was_new_record
      listing.save!
      [ listing, was_new_record ]
    rescue ActiveRecord::RecordNotUnique => error
      listing = find_listing(listing_source:, attributes:)
      raise error unless listing

      [ listing, false ]
    end

    def find_cross_source_listing(listing_source:, attributes:)
      signature = %i[title price_cents currency bedrooms].index_with { |key| attributes[key] }
      return if signature.values.any?(&:blank?)

      normalized_title = signature[:title].to_s.squish.downcase
      Listing
        .where.not(listing_source:)
        .where(price_cents: signature[:price_cents], currency: signature[:currency], bedrooms: signature[:bedrooms])
        .find { |listing| listing.title.to_s.squish.downcase == normalized_title }
    end

    def upsert_seen_listing(listing_source:, listing:, attributes:, scraping_run:)
      timestamp = Time.current
      seen_listing = find_seen_listing(listing_source:, attributes:) || SeenListing.new(listing_source:)
      was_new_record = seen_listing.new_record?
      seen_listing.listing = listing
      seen_listing.scraping_run = scraping_run if scraping_run && was_new_record
      seen_listing.external_id = attributes[:external_id]
      seen_listing.canonical_url = attributes[:canonical_url]
      seen_listing.first_seen_at ||= timestamp
      seen_listing.last_seen_at = timestamp
      seen_listing.save!
    rescue ActiveRecord::RecordNotUnique => error
      seen_listing = find_seen_listing(listing_source:, attributes:)
      raise error unless seen_listing

      seen_listing.listing = listing
      seen_listing.external_id = attributes[:external_id]
      seen_listing.canonical_url = attributes[:canonical_url]
      seen_listing.last_seen_at = timestamp
      seen_listing.save!
    end

    def find_seen_listing(listing_source:, attributes:)
      by_external_id = listing_source.seen_listings.find_by(external_id: attributes[:external_id]) if attributes[:external_id].present?
      return by_external_id if by_external_id

      listing_source.seen_listings.find_by(canonical_url: attributes[:canonical_url])
    end
  end
end
