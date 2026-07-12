class NotifyNewListingsJob < ActiveJob::Base
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(scraping_run_id)
    scraping_run = ScrapingRun.find(scraping_run_id)
    events = Notifications::NewListingFanOut.new.call(scraping_run: scraping_run)
    deliverer = Notifications::Deliverer.new

    events.each do |event|
      deliverer.call(notification_event: event)
    end
  end
end
