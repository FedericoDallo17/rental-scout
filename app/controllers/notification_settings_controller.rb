class NotificationSettingsController < ApplicationController
  def edit
  end

  def update
    if remove_key?
      current_user.update!(pushover_user_key: nil)
      redirect_to edit_notification_settings_path, notice: "Notification key removed."
    elsif submitted_key.present?
      current_user.update!(pushover_user_key: submitted_key)
      redirect_to edit_notification_settings_path, notice: "Notification settings saved."
    else
      redirect_to edit_notification_settings_path, notice: "Notification settings unchanged."
    end
  end

  private

  def settings_params
    @settings_params ||= params.require(:user).permit(:pushover_user_key, :remove_pushover_key)
  end

  def submitted_key
    settings_params[:pushover_user_key].to_s.strip
  end

  def remove_key?
    ActiveModel::Type::Boolean.new.cast(settings_params[:remove_pushover_key])
  end
end
