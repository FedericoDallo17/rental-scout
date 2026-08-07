require "net/http"
require "json"
require "openssl"
require "uri"

module Notifications
  class PushoverClient
    ENDPOINT_URI = URI("https://api.pushover.net/1/messages.json")
    VALIDATION_URI = URI("https://api.pushover.net/1/users/validate.json")
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15
    CONNECTION_ERRORS = [::Net::OpenTimeout, ::Net::ReadTimeout, ::SocketError, ::EOFError, ::IOError, ::SystemCallError, ::OpenSSL::SSL::SSLError].freeze

    class DeliveryError < StandardError; end
    class InvalidUserKey < DeliveryError; end
    class ServiceUnavailable < DeliveryError; end

    def initialize(api_token: nil)
      @api_token = api_token.presence || Rails.application.credentials.dig(:pushover, :api_token).presence || ENV["PUSHOVER_API_TOKEN"].presence
    end

    def deliver(user_key:, title:, message:, url: nil)
      ensure_api_token!

      response = post_message(api_token: @api_token, user_key: user_key, title: title, message: message, url: url)
      ensure_success!(response)

      true
    rescue *CONNECTION_ERRORS => error
      raise ServiceUnavailable, error.message
    end

    def validate_user_key!(user_key:)
      ensure_api_token!

      response = post_validation(api_token: @api_token, user_key: user_key)
      ensure_success!(response)

      true
    rescue *CONNECTION_ERRORS => error
      raise ServiceUnavailable, error.message
    end

    private

    def post_message(api_token:, user_key:, title:, message:, url:)
      ::Net::HTTP.start(
        ENDPOINT_URI.host,
        ENDPOINT_URI.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = ::Net::HTTP::Post.new(ENDPOINT_URI)
        request.set_form_data({ token: api_token, user: user_key, title: title, message: message, url: url }.compact)
        http.request(request)
      end
    end

    def post_validation(api_token:, user_key:)
      ::Net::HTTP.start(
        VALIDATION_URI.host,
        VALIDATION_URI.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = ::Net::HTTP::Post.new(VALIDATION_URI)
        request.set_form_data(token: api_token, user: user_key)
        http.request(request)
      end
    end

    def ensure_api_token!
      raise DeliveryError, "Pushover API token is not configured" if @api_token.blank?
    end

    def ensure_success!(response)
      return if response.is_a?(::Net::HTTPSuccess)

      error_message = "pushover returned #{response.code}: #{response.body}"
      raise InvalidUserKey, error_message if invalid_user_key_response?(response)
      raise ServiceUnavailable, error_message if response.code.to_i >= 500 || response.code.to_i == 429

      raise DeliveryError, error_message
    end

    def invalid_user_key_response?(response)
      payload = JSON.parse(response.body)
      payload.fetch("errors", []).any? { |error| error.to_s.downcase.include?("user") }
    rescue JSON::ParserError, TypeError
      false
    end
  end
end
