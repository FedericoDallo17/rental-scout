class NotificationSettingsController < ApplicationController
  def edit
    set_notification_searches
    @vapid_public_key = Notifications::VapidConfiguration.public_key
  end

  def update
    if submitted_key.present?
      pushover_client.validate_user_key!(user_key: submitted_key)
      current_user.update!(pushover_user_key: submitted_key)
      redirect_to edit_notification_settings_path, notice: t("flash.notification_saved")
    else
      redirect_to edit_notification_settings_path, notice: t("flash.notification_unchanged")
    end
  rescue Notifications::PushoverClient::InvalidUserKey
    redirect_to edit_notification_settings_path, alert: t("flash.notification_key_invalid")
  rescue Notifications::PushoverClient::DeliveryError
    redirect_to edit_notification_settings_path, alert: t("flash.notification_service_unavailable")
  end

  def test_delivery
    if current_user.push_subscriptions.none? && current_user.pushover_user_key.blank?
      redirect_to edit_notification_settings_path, alert: t("flash.notification_key_required")
      return
    end

    notification_dispatcher.deliver(
      user: current_user,
      title: t("notifications.test_title"),
      message: t("notifications.test_message"),
      url: listings_url
    )
    redirect_to edit_notification_settings_path, notice: t("flash.notification_test_sent")
  rescue Notifications::PushoverClient::InvalidUserKey
    redirect_to edit_notification_settings_path, alert: t("flash.notification_saved_key_invalid")
  rescue Notifications::PushoverClient::DeliveryError
    redirect_to edit_notification_settings_path, alert: t("flash.notification_test_failed")
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

  def pushover_client
    @pushover_client ||= Notifications::PushoverClient.new
  end

  def notification_dispatcher
    @notification_dispatcher ||= Notifications::Dispatcher.new
  end

  def set_notification_searches
    @notification_searches = current_user.search_preferences.where(notifications_enabled: true).ordered_for_sidebar
  end
end
