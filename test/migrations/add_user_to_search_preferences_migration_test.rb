require "test_helper"
require Rails.root.join("db/migrate/20260704110000_add_user_to_search_preferences")
require "securerandom"

class AddUserToSearchPreferencesMigrationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "assigns orphaned search preferences to the first user when one exists" do
    with_isolated_schema do |connection|
      create_legacy_users_table(connection)
      create_legacy_search_preferences_table(connection)

      connection.execute <<~SQL
        INSERT INTO users (id) VALUES (5), (9)
      SQL
      connection.execute <<~SQL
        INSERT INTO search_preferences (name, location_query, created_at, updated_at)
        VALUES
          ('Pocitos', 'Pocitos', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ('Centro', 'Centro', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      migrate_up

      assert_equal [5, 5], connection.select_values("SELECT user_id FROM search_preferences ORDER BY id").map(&:to_i)
      assert_equal false, connection.columns("search_preferences").find { |column| column.name == "user_id" }.null
    end
  end

  test "resets orphaned search preferences instead of failing when no users exist" do
    with_isolated_schema do |connection|
      create_legacy_users_table(connection)
      create_legacy_search_preferences_table(connection)

      connection.execute <<~SQL
        INSERT INTO search_preferences (name, location_query, created_at, updated_at)
        VALUES ('Pocitos', 'Pocitos', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      migrate_up

      assert_equal 0, connection.select_value("SELECT COUNT(*) FROM search_preferences").to_i
      assert_equal false, connection.columns("search_preferences").find { |column| column.name == "user_id" }.null
    end
  end

  test "nullifies dependent notification events before deleting orphaned search preferences" do
    with_isolated_schema do |connection|
      create_legacy_users_table(connection)
      create_legacy_search_preferences_table(connection)
      create_notification_events_table(connection)

      connection.execute <<~SQL
        INSERT INTO search_preferences (id, name, location_query, created_at, updated_at)
        VALUES (7, 'Pocitos', 'Pocitos', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.execute <<~SQL
        INSERT INTO notification_events (search_preference_id, event_kind, status, idempotency_key, created_at, updated_at)
        VALUES (7, 'listing_found', 'pending', 'migration-test-event', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      migrate_up

      assert_equal 0, connection.select_value("SELECT COUNT(*) FROM search_preferences").to_i
      assert_nil connection.select_value("SELECT search_preference_id FROM notification_events WHERE idempotency_key = 'migration-test-event'")
      assert_equal false, connection.columns("search_preferences").find { |column| column.name == "user_id" }.null
    end
  end

  test "restores notification event columns after using an isolated schema" do
    with_isolated_schema do |connection|
      create_legacy_search_preferences_table(connection)
      create_notification_events_table(connection)

      NotificationEvent.reset_column_information
      refute_includes NotificationEvent.column_names, "listing_id"
    end

    assert_includes NotificationEvent.column_names, "listing_id"
    assert_includes NotificationEvent.column_names, "listing_source_id"
  end

  private

  def migrate_up
    migration = AddUserToSearchPreferences.new

    migration.suppress_messages do
      migration.migrate(:up)
    end
  end

  def with_isolated_schema
    connection = ActiveRecord::Base.connection
    original_search_path = connection.schema_search_path
    schema_name = "migration_test_#{SecureRandom.hex(6)}"

    connection.execute(%(CREATE SCHEMA "#{schema_name}"))
    connection.schema_search_path = schema_name
    reset_schema_state(connection)

    yield connection
  ensure
    if connection && original_search_path
      connection.schema_search_path = original_search_path
      reset_schema_state(connection)
    end
    connection.execute(%(DROP SCHEMA IF EXISTS "#{schema_name}" CASCADE)) if connection && schema_name
  end

  def reset_schema_state(connection)
    connection.schema_cache.clear!
    [User, SearchPreference, NotificationEvent].each(&:reset_column_information)
  end

  def create_legacy_users_table(connection)
    connection.create_table :users, force: true do |t|
    end
  end

  def create_legacy_search_preferences_table(connection)
    connection.create_table :search_preferences, force: true do |t|
      t.string :name, null: false
      t.string :location_query, null: false
      t.integer :min_price_cents
      t.integer :max_price_cents
      t.integer :min_bedrooms
      t.boolean :notifications_enabled, null: false, default: true
      t.timestamps null: false
    end
  end

  def create_notification_events_table(connection)
    connection.create_table :notification_events, force: true do |t|
      t.references :search_preference, foreign_key: true
      t.string :event_kind, null: false
      t.string :status, null: false
      t.string :idempotency_key, null: false
      t.timestamps null: false
    end
  end
end
