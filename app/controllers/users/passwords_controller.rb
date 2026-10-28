require Rails.root.join("lib/smtp_configuration")

module Users
  class PasswordsController < Devise::PasswordsController
    def create
      super
    rescue SmtpConfiguration::NotConfigured, Net::SMTPError, IOError, SystemCallError,
      Timeout::Error, SocketError, OpenSSL::SSL::SSLError => error
      delivery_failed(error)
    end

    private

    def delivery_failed(error)
      # Never log SMTP responses, email addresses, or reset tokens.
      Rails.logger.error("Password recovery delivery failed (#{error.class})")
      self.resource = resource_class.new
      flash.now[:alert] = I18n.t("devise.passwords.delivery_failed")
      render :new, formats: [:html], status: :service_unavailable
    end
  end
end
