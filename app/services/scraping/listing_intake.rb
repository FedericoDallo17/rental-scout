module Scraping
  class ListingIntake
    def call(listing_source:, attributes:, scraping_run: nil)
      listing, was_new_record = persist_listing(listing_source:, attributes:, scraping_run:)

      upsert_seen_listing(listing_source:, listing:, attributes:, scraping_run:)

      listing.instance_variable_set(:@created_by_intake, was_new_record)
      listing
    end

    private

    def listing_attributes(attributes)
      attrs = Scraping::ListingGeometryBuilder.new.call(attributes: attributes.dup)
      attrs[:raw_payload] = attributes
      attrs
    end

    def find_listing(listing_source:, attributes:)
      by_external_id = listing_source.listings.find_by(external_id: attributes[:external_id]) if attributes[:external_id].present?
      return by_external_id if by_external_id

      listing_source.listings.find_by(canonical_url: attributes[:canonical_url])
    end

    def persist_listing(listing_source:, attributes:, scraping_run:)
      listing = find_listing(listing_source:, attributes:) || Listing.new(listing_source:)
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
