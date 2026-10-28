require "test_helper"
require_relative "../../lib/smtp_configuration"

class SmtpConfigurationTest < ActiveSupport::TestCase
  test "an unconfigured provider fails explicitly without contacting localhost" do
    assert_raises(SmtpConfiguration::NotConfigured) do
      SmtpConfiguration::UnconfiguredDelivery.new.deliver!(Object.new)
    end
  end

  def environment
    { "SMTP_ADDRESS" => "smtp.example.net", "APP_HOST" => "timbre.dallo.dev",
      "SMTP_USERNAME" => "test-user", "SMTP_PASSWORD" => "test-secret" }
  end

  test "SMTP requires an explicit authenticated server and verified STARTTLS" do
    settings = SmtpConfiguration.settings(environment)
    assert_equal "smtp.example.net", settings[:address]
    assert_equal 587, settings[:port]
    assert_equal "timbre.dallo.dev", settings[:domain]
    assert_equal :login, settings[:authentication]
    assert settings[:enable_starttls]
    assert_equal "peer", settings[:openssl_verify_mode]
    assert_equal 10, settings[:open_timeout]
    assert_equal 10, settings[:read_timeout]
  end

  test "implicit TLS uses port 465 and does not attempt STARTTLS" do
    settings = SmtpConfiguration.settings(environment.merge("SMTP_SSL" => "true"))
    assert settings[:ssl]
    assert_equal 465, settings[:port]
    refute settings[:enable_starttls]
  end

  test "missing or empty credentials cannot fall back to localhost" do
    %w[SMTP_ADDRESS APP_HOST SMTP_USERNAME SMTP_PASSWORD].each do |key|
      assert_raises(KeyError) { SmtpConfiguration.settings(environment.except(key)) }
      assert_raises(ArgumentError) { SmtpConfiguration.settings(environment.merge(key => " ")) }
    end
    assert_raises(ArgumentError) { SmtpConfiguration.settings(environment.merge("SMTP_PORT" => "invalid")) }
  end
end
