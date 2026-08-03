class LanguageSettingsController < ApplicationController
  skip_before_action :authenticate_user!, only: :update

  def update
    locale = params.require(:locale).to_s

    unless locale.in?(User::SUPPORTED_LOCALES)
      head :unprocessable_entity
      return
    end


    if current_user.present? && !current_user.update(locale:)
      head :unprocessable_entity
      return
    end

    cookies.permanent[:locale] = { value: locale, same_site: :lax }
    redirect_back fallback_location: (current_user.present? ? root_path : new_user_session_path),
      notice: I18n.t("flash.language_updated", locale: locale)
  end
end
