require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "creates, refreshes, and removes the current user's browser subscription" do
    user = create_push_test_user!
    sign_in user
    endpoint = "https://push.example.test/subscription-1"

    assert_difference("user.push_subscriptions.count", 1) do
      post push_subscriptions_path, params: {
        subscription: { endpoint:, keys: { p256dh: "public-key", auth: "auth-secret" } }
      }, as: :json
    end
    assert_response :created
    subscription = user.push_subscriptions.find_by!(endpoint:)
    assert_equal "public-key", subscription.p256dh

    assert_no_difference("PushSubscription.count") do
      post push_subscriptions_path, params: {
        subscription: { endpoint:, keys: { p256dh: "new-public-key", auth: "new-auth" } }
      }, as: :json
    end
    assert_equal "new-public-key", subscription.reload.p256dh

    assert_difference("user.push_subscriptions.count", -1) do
      delete current_push_subscriptions_path, params: { endpoint: }, as: :json
    end
    assert_response :no_content
  end

  test "does not let a guest register a subscription" do
    assert_no_difference("PushSubscription.count") do
      post push_subscriptions_path, params: {
        subscription: {
          endpoint: "https://push.example.test/guest",
          keys: { p256dh: "public-key", auth: "auth-secret" }
        }
      }, as: :json
    end

    assert_response :unauthorized
  end
end
