module Notifications
  class VapidConfiguration
    class << self
      def public_key
        key_pair.public_key.delete("=")
      end

      def private_key
        key_pair.private_key
      end

      def subject
        ENV.fetch("VAPID_SUBJECT") do
          host = Rails.application.config.action_mailer.default_url_options&.fetch(:host, nil)
          "https://#{host || 'localhost'}"
        end
      end

      private

      def key_pair
        @key_pair ||= begin
          group = OpenSSL::PKey::EC::Group.new("prime256v1")
          digest = OpenSSL::Digest::SHA256.digest("rental-scout-lite/web-push/v1/#{Rails.application.secret_key_base}")
          scalar = (OpenSSL::BN.new(digest, 2) % (group.order - 1)) + 1
          public_point = group.generator.mul(scalar)
          WebPush::VapidKey.from_keys(
            WebPush.encode64(public_point.to_bn.to_s(2)),
            WebPush.encode64(scalar.to_s(2).rjust(32, "\0"))
          )
        end
      end
    end
  end
end
