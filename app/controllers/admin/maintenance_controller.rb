module Admin
  class MaintenanceController < BaseController
    ACTIONS = {
      "scrape" => -> { RunScrapersJob.perform_later },
      "reconcile" => -> { RunScrapersJob.perform_later(reconciliation: true) },
      "purge" => -> { PurgeStaleListingsJob.perform_later },
      "backfill_coordinates" => -> { BackfillInfoCasasCoordinatesJob.perform_later }
    }.freeze

    def create
      operation = params.require(:maintenance).fetch(:operation)
      job = ACTIONS.fetch(operation) { raise ActiveRecord::RecordNotFound }

      if %w[scrape reconcile].include?(operation)
        if (active_run = scraping_run_in_progress)
          redirect_to admin_scraping_run_path(active_run), alert: t("admin.maintenance.run_in_progress")
          return
        end
      end

      job.call
      redirect_to admin_root_path, notice: t("admin.maintenance.enqueued.#{operation}")
    end

    private

    def scraping_run_in_progress
      ScrapingRun.close_abandoned!
      ScrapingRun.where(status: "running").order(started_at: :desc).first
    end
  end
end
