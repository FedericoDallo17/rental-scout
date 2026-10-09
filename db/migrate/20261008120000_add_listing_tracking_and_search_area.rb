class AddListingTrackingAndSearchArea < ActiveRecord::Migration[8.0]
  def change
    add_column :search_preferences, :min_square_meters, :integer
    add_column :search_preferences, :max_square_meters, :integer
    add_check_constraint :search_preferences,
      "(min_square_meters IS NULL OR min_square_meters >= 0) AND (max_square_meters IS NULL OR max_square_meters >= 0) AND (min_square_meters IS NULL OR max_square_meters IS NULL OR min_square_meters <= max_square_meters)",
      name: "search_preferences_area_range"

    create_table :listing_tracks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :listing, foreign_key: { on_delete: :nullify }
      t.string :source_key, null: false
      t.string :source_identity, null: false
      t.boolean :favorite, default: false, null: false
      t.date :contacted_on
      t.date :visited_on
      t.date :rejected_on
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps
    end
    add_index :listing_tracks, [:user_id, :source_key, :source_identity], unique: true, name: "index_listing_tracks_on_user_and_identity"
  end
end
