class PurgeStaleListingsJob < ActiveJob::Base
  queue_as :default

  def perform
    Scraping::PurgeStaleListings.new.call
  end
end
