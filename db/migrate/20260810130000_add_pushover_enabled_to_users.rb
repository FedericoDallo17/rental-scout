class AddPushoverEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :pushover_enabled, :boolean, null: false, default: true
  end
end
