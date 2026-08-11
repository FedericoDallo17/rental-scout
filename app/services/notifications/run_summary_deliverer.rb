module Notifications
  class RunSummaryDeliverer
    def initialize(client: PushoverClient.new)
      @client = client
    end

    def call(user:, events:, scraping_run:)
      return if events.empty?

      if user.pushover_user_key.blank?
        update_events(events, status: "skipped", delivery_error: "user has no pushover_user_key")
        return
      end

      listing_count = events.map(&:listing_id).uniq.size
      I18n.with_locale(user.locale) do
        @client.deliver(
          user_key: user.pushover_user_key,
          title: I18n.t("notifications.summary.title"),
          message: I18n.t("notifications.summary.message", count: listing_count),
          url: results_url(user, scraping_run)
        )
      end
      update_events(events, status: "sent", sent_at: Time.current, delivery_error: nil)
    rescue StandardError => error
      update_events(events, status: "failed", delivery_error: "#{error.class}: #{error.message}")
    end

    private

    def results_url(user, scraping_run)
      options = Rails.application.config.action_mailer.default_url_options || {}
      token = Rails.application.message_verifier(:notification_results).generate(
        { user_id: user.id, scraping_run_id: scraping_run.id, locale: user.locale },
        expires_in: 7.days,
        purpose: :notification_results
      )
      Rails.application.routes.url_helpers.notification_results_url(token:, **options)
    end

    def update_events(events, attributes)
      NotificationEvent.where(id: events.map(&:id)).update_all(attributes.merge(updated_at: Time.current))
    end
  end
end
