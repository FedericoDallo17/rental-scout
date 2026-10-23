class AddOperationTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :operation_type, :string, null: false, default: "alquiler"
    add_index :listings, :operation_type

    add_column :search_preferences, :operation_type, :string, null: false, default: "alquiler"
    add_index :search_preferences, :operation_type
  end
end
