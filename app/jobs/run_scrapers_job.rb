class RunScrapersJob < ActiveJob::Base
  queue_as :default

  def perform
    run = Scraping::RunOrchestrator.new.call
    NotifyNewListingsJob.perform_later(run.id)
    run
  end
end
