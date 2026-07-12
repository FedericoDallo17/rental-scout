class NotifyNewListingsJob < ActiveJob::Base
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(scraping_run_id)
    scraping_run = ScrapingRun.find(scraping_run_id)
    events = Notifications::NewListingFanOut.new.call(scraping_run: scraping_run)
    deliverer = Notifications::RunSummaryDeliverer.new

    events.group_by { |event| event.search_preference.user }.each do |user, user_events|
      deliverer.call(user:, events: user_events, scraping_run:)
    end
  end
end
