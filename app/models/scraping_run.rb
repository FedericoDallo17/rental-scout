class ScrapingRun < ApplicationRecord
  ABANDONED_AFTER = 2.hours

  has_many :listings, dependent: :nullify
  has_many :scraping_source_runs, dependent: :destroy
  has_many :seen_listings, dependent: :nullify

  validates :status, :started_at, presence: true

  def run_type
    reconciliation? ? "reconciliation" : "hourly"
  end

  def progress_listings_seen_count
    running? ? scraping_source_runs.sum(:listings_seen_count) : listings_seen_count
  end

  def progress_listings_created_count
    running? ? scraping_source_runs.sum(:listings_created_count) : listings_created_count
  end

  def running?
    status == "running"
  end

  def self.close_abandoned!
    where(status: "running")
      .where("started_at < ?", ABANDONED_AFTER.ago)
      .update_all(
        status: "failed",
        finished_at: Time.current,
        error_message: "Automatically closed after exceeding the maximum run time",
        updated_at: Time.current
      )
  end
end
