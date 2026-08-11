module Notifications
  class Dispatcher
    NoDeliveryChannel = Class.new(StandardError)
    Result = Data.define(:channel, :delivered_count)

    def initialize(web_push_client: WebPushClient.new, pushover_client: PushoverClient.new)
      @web_push_client = web_push_client
      @pushover_client = pushover_client
    end

    def deliver(user:, title:, message:, url:)
      web_push_result = @web_push_client.deliver(user:, title:, message:, url:)
      if web_push_result.delivered_count.positive?
        return Result.new(channel: "web_push", delivered_count: web_push_result.delivered_count)
      end

      if user.pushover_user_key.present?
        @pushover_client.deliver(user_key: user.pushover_user_key, title:, message:, url:)
        return Result.new(channel: "pushover", delivered_count: 1)
      end

      raise NoDeliveryChannel, "user has no active push subscription or Pushover key"
    end
  end
end
