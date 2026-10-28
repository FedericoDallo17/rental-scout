require "test_helper"

class PasswordRecoveryTest < ActionDispatch::IntegrationTest
  class RefusedDelivery
    def initialize(_settings = {}); end

    def deliver!(_mail)
      raise Errno::ECONNREFUSED
    end
  end

  setup do
    @user = User.create!(first_name: "Recovery", last_name: "Test",
      email: "recovery@example.com", password: "old-password123", locale: "es")
    ActionMailer::Base.deliveries.clear
  end

  test "recovery sends a localized email and its link changes the password only once" do
    post user_password_path, params: { user: { email: @user.email } }
    assert_redirected_to new_user_session_path
    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal [@user.email], mail.to
    assert_equal [ENV.fetch("MAIL_FROM", "notifications@timbre.dallo.dev")], mail.from
    assert_equal "Instrucciones para restablecer la contraseña", mail.subject
    body = mail.body.decoded
    assert_includes body, "Cambiar mi contraseña"
    link = Nokogiri::HTML(body).at_css("a")["href"]
    uri = URI(link)
    assert_equal "example.com", uri.host
    token = Rack::Utils.parse_query(uri.query).fetch("reset_password_token")
    assert @user.reload.valid_password?("old-password123")

    get uri.request_uri
    assert_response :success
    put user_password_path, params: { user: { reset_password_token: token,
      password: "new-password456", password_confirmation: "new-password456" } }
    assert_response :redirect
    assert @user.reload.valid_password?("new-password456")
    refute @user.valid_password?("old-password123")
    assert_nil @user.reset_password_token

    delete destroy_user_session_path
    put user_password_path, params: { user: { reset_password_token: token,
      password: "replayed-password", password_confirmation: "replayed-password" } }
    assert_response :unprocessable_content
    assert @user.reload.valid_password?("new-password456")

    post user_session_path, params: { user: { email: @user.email, password: "new-password456" } }
    assert_response :redirect
  end

  test "expired recovery links cannot change a password" do
    token = @user.send_reset_password_instructions
    @user.update_column(:reset_password_sent_at, 7.hours.ago)
    put user_password_path, params: { user: { reset_password_token: token,
      password: "new-password456", password_confirmation: "new-password456" } }
    assert_response :unprocessable_content
    assert @user.reload.valid_password?("old-password123")
  end

  test "SMTP outage offers a retry instead of an unhandled server error" do
    assert_delivery_failure(RefusedDelivery)
  end

  test "an unconfigured provider never claims an email was sent" do
    assert_delivery_failure(SmtpConfiguration::UnconfiguredDelivery)
    assert_empty ActionMailer::Base.deliveries
  end

  test "English accounts receive English recovery mail even from a Spanish request" do
    @user.update!(locale: "en")
    post user_password_path, params: { user: { email: @user.email } },
      headers: { "Accept-Language" => "es" }
    assert_response :redirect
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Reset password instructions", mail.subject
    assert_includes mail.body.decoded, "Change my password"
  end

  private

  def assert_delivery_failure(delivery_method)
    original_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = delivery_method
    post user_password_path, params: { user: { email: @user.email } },
      headers: { "Accept" => "text/vnd.turbo-stream.html", "Accept-Language" => "es" }
    assert_response :service_unavailable
    assert_select "form.auth-form"
    assert_includes response.body, "No pudimos enviar el correo"
    refute_includes response.body, "En unos minutos recibirás"
  ensure
    ActionMailer::Base.delivery_method = original_method
  end
end
