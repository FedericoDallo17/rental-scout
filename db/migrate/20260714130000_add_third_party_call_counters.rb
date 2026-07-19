class AddThirdPartyCallCounters < ActiveRecord::Migration[8.0]
  def change
    add_column :listing_sources, :third_party_calls_count, :bigint, default: 0, null: false
    add_column :scraping_source_runs, :third_party_calls_count, :integer, default: 0, null: false
  end
end
