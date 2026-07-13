class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  around_action :switch_locale

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :pushover_user_key])
  end

  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end

  def switch_locale(&action)
    locale = current_user&.locale.presence || I18n.default_locale
    I18n.with_locale(locale, &action)
  end
end
