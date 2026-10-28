# Shared by the production configuration and its isolated configuration tests.
module SmtpConfiguration
  class NotConfigured < StandardError; end

  class UnconfiguredDelivery
    def initialize(_settings = {}); end

    def deliver!(_mail)
      raise NotConfigured, "A mail provider must be configured before sending email"
    end
  end

  def self.settings(env = ENV)
    ssl = env.fetch("SMTP_SSL", "false") == "true"
    {
      address: env.fetch("SMTP_ADDRESS"),
      port: Integer(env.fetch("SMTP_PORT", ssl ? "465" : "587")),
      domain: env.fetch("APP_HOST"),
      user_name: env.fetch("SMTP_USERNAME"),
      password: env.fetch("SMTP_PASSWORD"),
      authentication: :login,
      ssl: ssl,
      enable_starttls: !ssl,
      openssl_verify_mode: "peer",
      open_timeout: 10,
      read_timeout: 10
    }.tap do |settings|
      %i[address domain user_name password].each do |key|
        raise ArgumentError, "SMTP configuration requires #{key}" if settings[key].strip.empty?
      end
    end
  end
end
