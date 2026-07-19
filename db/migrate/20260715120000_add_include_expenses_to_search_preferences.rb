class AddIncludeExpensesToSearchPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :search_preferences, :include_expenses, :boolean, default: false, null: false
  end
end
