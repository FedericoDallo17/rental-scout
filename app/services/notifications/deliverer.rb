module Notifications
  class Deliverer
    def initialize(client: PushoverClient.new)
      @client = client
    end

    def call(notification_event:)
      user = notification_event.search_preference&.user
      listing = notification_event.listing

      if user&.pushover_user_key.blank?
        notification_event.update!(status: "skipped", delivery_error: "user has no pushover_user_key")
        return
      end

      @client.deliver(
        user_key: user.pushover_user_key,
        title: "New match: #{notification_event.search_preference.name}",
        message: "#{listing.title} - #{formatted_price(listing)}",
        url: listing.canonical_url
      )
      notification_event.update!(status: "sent", sent_at: Time.current, delivery_error: nil)
    rescue StandardError => error
      notification_event.update!(status: "failed", delivery_error: "#{error.class}: #{error.message}")
    end

    private

    def formatted_price(listing)
      return "price unknown" if listing.price_cents.blank?

      "#{listing.currency} #{listing.price_cents / 100}"
    end
  end
end
