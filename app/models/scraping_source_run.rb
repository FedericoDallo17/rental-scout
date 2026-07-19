class ScrapingSourceRun < ApplicationRecord
  belongs_to :listing_source
  belongs_to :scraping_run

  validates :status, :started_at, presence: true

  after_commit :broadcast_parent_progress

  private

  def broadcast_parent_progress
    scraping_run.broadcast_admin_progress
  end
end
