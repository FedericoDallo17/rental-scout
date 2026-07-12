require "net/http"
require "uri"

module Notifications
  class PushoverClient
    ENDPOINT_URI = URI("https://api.pushover.net/1/messages.json")
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15

    class DeliveryError < StandardError; end

    def initialize(api_token: nil)
      @api_token = api_token.presence || Rails.application.credentials.dig(:pushover, :api_token).presence || ENV["PUSHOVER_API_TOKEN"].presence
    end

    def deliver(user_key:, title:, message:, url: nil)
      raise DeliveryError, "Pushover API token is not configured" if @api_token.blank?

      response = post_message(api_token: @api_token, user_key: user_key, title: title, message: message, url: url)
      raise DeliveryError, "pushover returned #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      true
    end

    private

    def post_message(api_token:, user_key:, title:, message:, url:)
      Net::HTTP.start(
        ENDPOINT_URI.host,
        ENDPOINT_URI.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Post.new(ENDPOINT_URI)
        request.set_form_data({ token: api_token, user: user_key, title: title, message: message, url: url }.compact)
        http.request(request)
      end
    end
  end
end
