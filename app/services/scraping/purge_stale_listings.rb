module Scraping
  class PurgeStaleListings
    BATCH_SIZE = 100
    STALE_AFTER = 7.days
    Result = Struct.new(:listings_deleted_count, :notification_events_deleted_count, keyword_init: true)

    def call(now: Time.current)
      cutoff = now - STALE_AFTER
      listings_deleted_count = 0
      notification_events_deleted_count = 0

      Listing.where("updated_at < ?", cutoff).in_batches(of: BATCH_SIZE) do |relation|
        Listing.transaction do
          listings = relation.to_a
          listing_ids = listings.map(&:id)
          next if listing_ids.empty?

          notification_events_deleted_count += NotificationEvent.where(listing_id: listing_ids).delete_all

          listings.each do |listing|
            listing.destroy!
            listings_deleted_count += 1
          end
        end
      end

      Rails.logger.info(
        "[PurgeStaleListings] deleted #{listings_deleted_count} stale listings and #{notification_events_deleted_count} notification events"
      )

      Result.new(
        listings_deleted_count: listings_deleted_count,
        notification_events_deleted_count: notification_events_deleted_count
      )
    end
  end
end
