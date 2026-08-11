module Notifications
  class BrowserDeliverer
    def initialize(client: WebPushClient.new)
      @client = client
    end

    def call(user:, events:)
      events.group_by(&:listing_id).each_value do |listing_events|
        deliver_listing(user:, events: listing_events)
      end
    end

    private

    def deliver_listing(user:, events:)
      event = events.first
      listing = event.listing
      result = I18n.with_locale(user.locale) do
        @client.deliver(
          user:,
          title: I18n.t("notifications.delivery.title", search: event.search_preference.name),
          message: I18n.t("notifications.delivery.message", title: listing.title, price: formatted_price(listing)),
          url: listing.canonical_url
        )
      end

      if result.delivered_count.positive?
        update_events(events, channel: "web_push", status: "sent", sent_at: Time.current, delivery_error: nil)
      else
        update_events(events, channel: "web_push", status: "failed", delivery_error: "no browser subscription received notification")
      end
    rescue StandardError => error
      update_events(events, channel: "web_push", status: "failed", delivery_error: "#{error.class}: #{error.message}")
    end

    def formatted_price(listing)
      return I18n.t("notifications.delivery.price_unknown") if listing.price_cents.blank?

      MoneyFormatter.call(listing.price_cents, listing.currency)
    end

    def update_events(events, attributes)
      NotificationEvent.where(id: events.map(&:id)).update_all(attributes.merge(updated_at: Time.current))
    end
  end
end
