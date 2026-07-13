class LanguageSettingsController < ApplicationController
  def update
    locale = params.require(:locale).to_s
    if current_user.update(locale:)
      redirect_back fallback_location: root_path,
        notice: I18n.t("flash.language_updated", locale: locale)
    else
      head :unprocessable_entity
    end
  end
end
