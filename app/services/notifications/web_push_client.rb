module Notifications
  class WebPushClient
    DeliveryResult = Data.define(:delivered_count, :failed_count)

    def initialize(gateway: WebPush)
      @gateway = gateway
    end

    def deliver(user:, title:, message:, url:)
      delivered_count = 0
      failed_count = 0

      user.push_subscriptions.find_each do |subscription|
        send_payload(subscription:, title:, message:, url:)
        delivered_count += 1
      rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
        subscription.destroy!
      rescue WebPush::Error
        failed_count += 1
      end

      DeliveryResult.new(delivered_count:, failed_count:)
    end

    private

    def send_payload(subscription:, title:, message:, url:)
      @gateway.payload_send(
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        message: JSON.generate(title:, body: message, url:, tag: "rental-scout-new-listings"),
        vapid: {
          subject: VapidConfiguration.subject,
          public_key: VapidConfiguration.public_key,
          private_key: VapidConfiguration.private_key
        },
        ttl: 1.hour.to_i,
        urgency: "high",
        open_timeout: 5,
        read_timeout: 10
      )
    end
  end
end
