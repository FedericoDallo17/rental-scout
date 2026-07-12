require "test_helper"

class Notifications::PushoverClientTest < ActiveSupport::TestCase
  test "raises a clear error when no API token is configured" do
    client = Notifications::PushoverClient.allocate
    client.instance_variable_set(:@api_token, nil)

    error = assert_raises(Notifications::PushoverClient::DeliveryError) do
      client.deliver(user_key: "user-key", title: "Title", message: "Message")
    end

    assert_equal "Pushover API token is not configured", error.message
  end

  test "accepts an explicitly supplied API token" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    client_class = Class.new(Notifications::PushoverClient) do
      define_method(:post_message) do |**|
        response
      end
    end
    client = client_class.new(api_token: "app-token")

    assert client.deliver(user_key: "user-key", title: "Title", message: "Message")
  end
end
