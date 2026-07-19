class CloseAbandonedScrapingRuns < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE scraping_runs
      SET status = 'failed',
          finished_at = CURRENT_TIMESTAMP,
          error_message = 'Automatically closed after exceeding the maximum run time',
          updated_at = CURRENT_TIMESTAMP
      WHERE status = 'running'
        AND started_at < CURRENT_TIMESTAMP - INTERVAL '2 hours'
    SQL
  end

  def down
  end
end
