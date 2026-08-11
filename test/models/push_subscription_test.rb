require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  test "requires a unique HTTPS endpoint" do
    user = create_push_test_user!
    subscription = user.push_subscriptions.new(endpoint: "http://push.example.test/1", p256dh: "key", auth: "auth")

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "must use HTTPS"
  end
end
