class AddReconciliationToScrapingRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :scraping_runs, :reconciliation, :boolean, default: false, null: false
  end
end
