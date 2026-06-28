class ReshapeScrapingRuns < ActiveRecord::Migration[8.0]
  def up
    create_table :scraping_source_runs do |t|
      t.references :scraping_run, null: false, foreign_key: true
      t.references :listing_source, null: false, foreign_key: true
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :listings_seen_count, null: false, default: 0
      t.integer :listings_created_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    execute <<~SQL
      INSERT INTO scraping_source_runs (
        scraping_run_id,
        listing_source_id,
        status,
        started_at,
        finished_at,
        listings_seen_count,
        listings_created_count,
        error_message,
        created_at,
        updated_at
      )
      SELECT
        id,
        listing_source_id,
        status,
        started_at,
        finished_at,
        listings_seen_count,
        listings_created_count,
        error_message,
        created_at,
        updated_at
      FROM scraping_runs
      WHERE listing_source_id IS NOT NULL
    SQL

    remove_reference :scraping_runs, :listing_source, foreign_key: true
  end

  def down
    add_reference :scraping_runs, :listing_source, foreign_key: true

    execute <<~SQL
      UPDATE scraping_runs
      SET listing_source_id = source_runs.listing_source_id
      FROM (
        SELECT DISTINCT ON (scraping_run_id)
          scraping_run_id,
          listing_source_id
        FROM scraping_source_runs
        ORDER BY scraping_run_id, id
      ) AS source_runs
      WHERE scraping_runs.id = source_runs.scraping_run_id
    SQL

    drop_table :scraping_source_runs
  end
end
