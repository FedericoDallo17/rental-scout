class NotificationResultsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    payload = notification_payload
    return head :not_found unless payload

    @listings = NotificationEvent
      .joins(:search_preference, :listing)
      .where(search_preferences: { user_id: payload.fetch("user_id") })
      .where(listings: { scraping_run_id: payload.fetch("scraping_run_id") })
      .includes(listing: :listing_source)
      .map(&:listing)
      .uniq(&:id)

    head :not_found if @listings.empty?
  end

  private

  def switch_locale(&action)
    locale = notification_payload&.fetch("locale", nil).presence_in(User::SUPPORTED_LOCALES) ||
      persisted_locale || browser_locale || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def notification_payload
    Rails.application.message_verifier(:notification_results).verified(
      params[:token],
      purpose: :notification_results
    )
  end
end
