# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_13_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "listing_sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "adapter_key", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["adapter_key"], name: "index_listing_sources_on_adapter_key", unique: true
  end

  create_table "listings", force: :cascade do |t|
    t.bigint "listing_source_id", null: false
    t.bigint "scraping_run_id"
    t.string "title", null: false
    t.string "canonical_url", null: false
    t.string "external_id"
    t.integer "price_cents"
    t.string "currency"
    t.string "location_text"
    t.integer "bedrooms"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "square_meters"
    t.text "description"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "source_neighborhood"
    t.string "location_resolution_status", default: "unresolved", null: false
    t.boolean "in_scope", default: true, null: false
    t.string "scope_rejection_reason"
    t.geography "coordinates", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.integer "expenses_cents"
    t.string "expenses_currency"
    t.integer "parking_spaces"
    t.string "property_type"
    t.index ["coordinates"], name: "index_listings_on_coordinates", using: :gist
    t.index ["in_scope"], name: "index_listings_on_in_scope"
    t.index ["listing_source_id", "canonical_url"], name: "index_listings_on_listing_source_id_and_canonical_url", unique: true
    t.index ["listing_source_id", "external_id"], name: "index_listings_on_listing_source_id_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["listing_source_id"], name: "index_listings_on_listing_source_id"
    t.index ["location_resolution_status"], name: "index_listings_on_location_resolution_status"
    t.index ["scraping_run_id"], name: "index_listings_on_scraping_run_id"
  end

  create_table "notification_events", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.bigint "listing_source_id", null: false
    t.bigint "search_preference_id"
    t.string "event_kind", null: false
    t.string "channel"
    t.string "status", null: false
    t.string "idempotency_key", null: false
    t.datetime "sent_at"
    t.text "delivery_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_notification_events_on_idempotency_key", unique: true
    t.index ["listing_id"], name: "index_notification_events_on_listing_id"
    t.index ["listing_source_id"], name: "index_notification_events_on_listing_source_id"
    t.index ["search_preference_id"], name: "index_notification_events_on_search_preference_id"
  end

  create_table "scraping_runs", force: :cascade do |t|
    t.string "status", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "listings_seen_count", default: 0, null: false
    t.integer "listings_created_count", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scraping_source_runs", force: :cascade do |t|
    t.bigint "scraping_run_id", null: false
    t.bigint "listing_source_id", null: false
    t.string "status", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "listings_seen_count", default: 0, null: false
    t.integer "listings_created_count", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_source_id"], name: "index_scraping_source_runs_on_listing_source_id"
    t.index ["scraping_run_id"], name: "index_scraping_source_runs_on_scraping_run_id"
  end

  create_table "search_preferences", force: :cascade do |t|
    t.string "name", null: false
    t.string "location_query", null: false
    t.integer "min_price_cents"
    t.integer "max_price_cents"
    t.integer "min_bedrooms"
    t.boolean "notifications_enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "price_currency", default: "UYU", null: false
    t.index ["user_id"], name: "index_search_preferences_on_user_id"
  end

  create_table "search_zones", force: :cascade do |t|
    t.bigint "search_preference_id", null: false
    t.bigint "zone_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["search_preference_id", "zone_id"], name: "index_search_zones_on_search_preference_id_and_zone_id", unique: true
    t.index ["search_preference_id"], name: "index_search_zones_on_search_preference_id"
    t.index ["zone_id"], name: "index_search_zones_on_zone_id"
  end

  create_table "seen_listings", force: :cascade do |t|
    t.bigint "listing_source_id", null: false
    t.bigint "listing_id"
    t.bigint "scraping_run_id"
    t.string "external_id"
    t.string "canonical_url", null: false
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_seen_listings_on_listing_id"
    t.index ["listing_source_id", "canonical_url"], name: "index_seen_listings_on_listing_source_id_and_canonical_url", unique: true
    t.index ["listing_source_id", "external_id"], name: "index_seen_listings_on_listing_source_id_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["listing_source_id"], name: "index_seen_listings_on_listing_source_id"
    t.index ["scraping_run_id"], name: "index_seen_listings_on_scraping_run_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "pushover_user_key"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", default: "en", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "zones", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "aliases", default: [], null: false, array: true
    t.geography "geom", limit: {:srid=>4326, :type=>"multi_polygon", :geographic=>true}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_key"
    t.string "source_url"
    t.string "source_feature_id"
    t.index ["geom"], name: "index_zones_on_geom", using: :gist
    t.index ["slug"], name: "index_zones_on_slug", unique: true
    t.index ["source_key", "source_feature_id"], name: "index_zones_on_source_key_and_source_feature_id", unique: true, where: "((source_key IS NOT NULL) AND (source_feature_id IS NOT NULL))"
  end

  add_foreign_key "listings", "listing_sources"
  add_foreign_key "listings", "scraping_runs"
  add_foreign_key "notification_events", "listing_sources"
  add_foreign_key "notification_events", "listings"
  add_foreign_key "notification_events", "search_preferences"
  add_foreign_key "scraping_source_runs", "listing_sources"
  add_foreign_key "scraping_source_runs", "scraping_runs"
  add_foreign_key "search_preferences", "users"
  add_foreign_key "search_zones", "search_preferences"
  add_foreign_key "search_zones", "zones"
  add_foreign_key "seen_listings", "listing_sources"
  add_foreign_key "seen_listings", "listings"
  add_foreign_key "seen_listings", "scraping_runs"
end
