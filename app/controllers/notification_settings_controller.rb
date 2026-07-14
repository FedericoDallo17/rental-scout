class NotificationSettingsController < ApplicationController
  def edit
  end

  def update
    if submitted_key.present?
      current_user.update!(pushover_user_key: submitted_key)
      redirect_to edit_notification_settings_path, notice: t("flash.notification_saved")
    else
      redirect_to edit_notification_settings_path, notice: t("flash.notification_unchanged")
    end
  end

  def destroy
    current_user.update!(pushover_user_key: nil)
    redirect_to edit_notification_settings_path, notice: t("flash.notification_removed")
  end

  private

  def settings_params
    @settings_params ||= params.require(:user).permit(:pushover_user_key)
  end

  def submitted_key
    settings_params[:pushover_user_key].to_s.strip
  end
end
