class RunScrapersJob < ActiveJob::Base
  queue_as :default

  def perform(reconciliation: false)
    run = Scraping::RunOrchestrator.new.call(reconciliation:)
    NotifyNewListingsJob.perform_later(run.id) unless reconciliation
    run
  end
end
