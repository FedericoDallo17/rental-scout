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

      I18n.with_locale(user.locale) do
        @client.deliver(
          user_key: user.pushover_user_key,
          title: I18n.t("notifications.delivery.title", search: notification_event.search_preference.name),
          message: I18n.t("notifications.delivery.message", title: listing.title, price: formatted_price(listing)),
          url: listing.canonical_url
        )
      end
      notification_event.update!(status: "sent", sent_at: Time.current, delivery_error: nil)
    rescue StandardError => error
      notification_event.update!(status: "failed", delivery_error: "#{error.class}: #{error.message}")
    end

    private

    def formatted_price(listing)
      return I18n.t("notifications.delivery.price_unknown") if listing.price_cents.blank?

      MoneyFormatter.call(listing.price_cents, listing.currency)
    end
  end
end
