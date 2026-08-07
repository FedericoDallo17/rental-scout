require "test_helper"
require "net/http"

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
    response = ::Net::HTTPOK.new("1.1", "200", "OK")
    client_class = Class.new(Notifications::PushoverClient) do
      define_method(:post_message) do |**|
        response
      end
    end
    client = client_class.new(api_token: "app-token")

    assert client.deliver(user_key: "user-key", title: "Title", message: "Message")
  end

  test "validates a user key with Pushover" do
    response = ::Net::HTTPOK.new("1.1", "200", "OK")
    client_class = Class.new(Notifications::PushoverClient) do
      define_method(:post_validation) do |api_token:, user_key:|
        @validated_attributes = { api_token: api_token, user_key: user_key }
        response
      end
      attr_reader :validated_attributes
    end
    client = client_class.new(api_token: "app-token")

    assert client.validate_user_key!(user_key: "user-key")
    assert_equal({ api_token: "app-token", user_key: "user-key" }, client.validated_attributes)
  end

  test "distinguishes an invalid user key from other delivery errors" do
    response = ::Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, '{"errors":["user identifier is not valid"],"status":0}')
    client_class = Class.new(Notifications::PushoverClient) do
      define_method(:post_validation) { |**| response }
    end

    assert_raises(Notifications::PushoverClient::InvalidUserKey) do
      client_class.new(api_token: "app-token").validate_user_key!(user_key: "bad-key")
    end
  end

  test "reports provider outages as unavailable" do
    response = ::Net::HTTPServiceUnavailable.new("1.1", "503", "Unavailable")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, "temporarily unavailable")
    client_class = Class.new(Notifications::PushoverClient) do
      define_method(:post_validation) { |**| response }
    end

    assert_raises(Notifications::PushoverClient::ServiceUnavailable) do
      client_class.new(api_token: "app-token").validate_user_key!(user_key: "user-key")
    end
  end
end
