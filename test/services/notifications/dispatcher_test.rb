require "test_helper"

class Notifications::DispatcherTest < ActiveSupport::TestCase
  test "prefers Web Push and does not duplicate through Pushover" do
    user = create_push_test_user!
    user.update!(pushover_user_key: "fallback-key")
    push_client = Object.new
    push_client.define_singleton_method(:deliver) do |**|
      Notifications::WebPushClient::DeliveryResult.new(delivered_count: 2, failed_count: 0)
    end
    pushover_client = Object.new
    pushover_client.define_singleton_method(:deliver) { |**| flunk "Pushover should not be called" }

    result = Notifications::Dispatcher.new(web_push_client: push_client, pushover_client:).deliver(
      user:, title: "Title", message: "Body", url: "https://example.test"
    )

    assert_equal "web_push", result.channel
    assert_equal 2, result.delivered_count
  end

  test "falls back to Pushover when no browser receives the notification" do
    user = create_push_test_user!
    user.update!(pushover_user_key: "fallback-key")
    push_client = Object.new
    push_client.define_singleton_method(:deliver) do |**|
      Notifications::WebPushClient::DeliveryResult.new(delivered_count: 0, failed_count: 1)
    end
    deliveries = []
    pushover_client = Object.new
    pushover_client.define_singleton_method(:deliver) { |**attributes| deliveries << attributes }

    result = Notifications::Dispatcher.new(web_push_client: push_client, pushover_client:).deliver(
      user:, title: "Title", message: "Body", url: "https://example.test"
    )

    assert_equal "pushover", result.channel
    assert_equal "fallback-key", deliveries.first.fetch(:user_key)
  end
end
