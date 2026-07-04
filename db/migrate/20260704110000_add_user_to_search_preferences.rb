class AddUserToSearchPreferences < ActiveRecord::Migration[8.0]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  class MigrationSearchPreference < ApplicationRecord
    self.table_name = "search_preferences"
  end

  class MigrationNotificationEvent < ApplicationRecord
    self.table_name = "notification_events"
  end

  def up
    add_reference :search_preferences, :user, foreign_key: true, index: true

    default_user = MigrationUser.order(:id).first

    if default_user.present?
      MigrationSearchPreference.where(user_id: nil).update_all(user_id: default_user.id)
    elsif MigrationSearchPreference.exists?
      orphaned_search_preferences = MigrationSearchPreference.where(user_id: nil)

      if table_exists?(:notification_events)
        MigrationNotificationEvent.where(search_preference_id: orphaned_search_preferences.select(:id)).update_all(search_preference_id: nil)
      end

      orphaned_search_preferences.delete_all
    end

    change_column_null :search_preferences, :user_id, false
  end

  def down
    remove_reference :search_preferences, :user, foreign_key: true, index: true
  end
end
