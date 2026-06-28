class CreateCoreModels < ActiveRecord::Migration[8.0]
  def change
    create_table :listing_sources do |t|
      t.string :name, null: false
      t.string :adapter_key, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :listing_sources, :adapter_key, unique: true

    create_table :search_preferences do |t|
      t.string :name, null: false
      t.string :location_query, null: false
      t.integer :min_price_cents
      t.integer :max_price_cents
      t.integer :min_bedrooms
      t.boolean :notifications_enabled, null: false, default: true

      t.timestamps
    end

    create_table :scraping_runs do |t|
      t.references :listing_source, null: false, foreign_key: true
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :listings_seen_count, null: false, default: 0
      t.integer :listings_created_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    create_table :listings do |t|
      t.references :listing_source, null: false, foreign_key: true
      t.references :scraping_run, foreign_key: true
      t.string :title, null: false
      t.string :canonical_url, null: false
      t.string :external_id
      t.integer :price_cents
      t.string :currency
      t.string :location_text
      t.integer :bedrooms
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :listings, [ :listing_source_id, :canonical_url ], unique: true

    create_table :seen_listings do |t|
      t.references :listing_source, null: false, foreign_key: true
      t.references :listing, foreign_key: true
      t.references :scraping_run, foreign_key: true
      t.string :external_id
      t.string :canonical_url, null: false
      t.datetime :first_seen_at
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :seen_listings, [ :listing_source_id, :external_id ], unique: true, where: "external_id IS NOT NULL"
    add_index :seen_listings, [ :listing_source_id, :canonical_url ], unique: true

    create_table :notification_events do |t|
      t.references :listing, null: false, foreign_key: true
      t.references :listing_source, null: false, foreign_key: true
      t.references :search_preference, foreign_key: true
      t.string :event_kind, null: false
      t.string :channel
      t.string :status, null: false
      t.string :idempotency_key, null: false
      t.datetime :sent_at
      t.text :delivery_error

      t.timestamps
    end

    add_index :notification_events, :idempotency_key, unique: true
  end
end
