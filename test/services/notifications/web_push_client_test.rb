require "test_helper"

class Notifications::WebPushClientTest < ActiveSupport::TestCase
  test "delivers JSON payloads to every browser subscription" do
    user = create_push_test_user!
    2.times do |index|
      user.push_subscriptions.create!(
        endpoint: "https://push.example.test/#{index}", p256dh: "key-#{index}", auth: "auth-#{index}"
      )
    end
    deliveries = []
    gateway = Object.new
    gateway.define_singleton_method(:payload_send) { |**attributes| deliveries << attributes }

    result = Notifications::WebPushClient.new(gateway:).deliver(
      user:, title: "New homes", message: "Two matches", url: "https://homes.example.test/results"
    )

    assert_equal 2, result.delivered_count
    assert_equal 0, result.failed_count
    assert_equal 2, deliveries.size
    payload = JSON.parse(deliveries.first.fetch(:message))
    assert_equal "New homes", payload.fetch("title")
    assert_equal "https://homes.example.test/results", payload.fetch("url")
    assert_equal Notifications::VapidConfiguration.public_key, deliveries.first.dig(:vapid, :public_key)
  end

  test "removes expired subscriptions" do
    user = create_push_test_user!
    subscription = user.push_subscriptions.create!(
      endpoint: "https://push.example.test/expired", p256dh: "key", auth: "auth"
    )
    gateway = Object.new
    gateway.define_singleton_method(:payload_send) { |**| raise WebPush::ExpiredSubscription.allocate }

    result = Notifications::WebPushClient.new(gateway:).deliver(
      user:, title: "Title", message: "Body", url: "https://homes.example.test"
    )

    assert_equal 0, result.delivered_count
    assert_not PushSubscription.exists?(subscription.id)
  end
end
