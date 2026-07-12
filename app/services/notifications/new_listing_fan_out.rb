module Notifications
  class NewListingFanOut
    def call(scraping_run:)
      new_listing_ids = Listing.where(scraping_run: scraping_run).select(:id)
      created_events = []

      SearchPreference.where(notifications_enabled: true).find_each do |search|
        Listing.for_search_feed(search)
          .where(id: new_listing_ids)
          .includes(:listing_source)
          .find_each do |listing|
            event = create_event(search: search, listing: listing)
            created_events << event if event
          end
      end

      created_events
    end

    private

    def create_event(search:, listing:)
      key = "new_listing/listing-#{listing.id}/search-#{search.id}"
      return if NotificationEvent.exists?(idempotency_key: key)

      NotificationEvent.create!(
        listing: listing,
        listing_source: listing.listing_source,
        search_preference: search,
        event_kind: "new_listing",
        channel: "pushover",
        status: "pending",
        idempotency_key: key
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      nil
    end
  end
end
