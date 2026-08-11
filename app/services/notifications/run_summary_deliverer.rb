module Notifications
  class RunSummaryDeliverer
    def initialize(client: nil, dispatcher: nil)
      @dispatcher = dispatcher || Dispatcher.new(pushover_client: client || PushoverClient.new)
    end

    def call(user:, events:, scraping_run:)
      return if events.empty?

      listing_count = events.map(&:listing_id).uniq.size
      result = I18n.with_locale(user.locale) do
        @dispatcher.deliver(
          user:,
          title: I18n.t("notifications.summary.title"),
          message: I18n.t("notifications.summary.message", count: listing_count),
          url: results_url(user, scraping_run)
        )
      end
      update_events(events, channel: result.channel, status: "sent", sent_at: Time.current, delivery_error: nil)
    rescue Dispatcher::NoDeliveryChannel => error
      update_events(events, status: "skipped", delivery_error: error.message)
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
