class RunScrapersJob < ActiveJob::Base
  queue_as :default

  def perform
    Scraping::RunOrchestrator.new.call
  end
end
