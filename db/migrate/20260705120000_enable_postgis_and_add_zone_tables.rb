class EnablePostgisAndAddZoneTables < ActiveRecord::Migration[8.0]
  def change
    enable_extension "postgis"

    create_table :zones do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :aliases, array: true, default: [], null: false
      t.multi_polygon :geom, geographic: true, srid: 4326, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :zones, :slug, unique: true
    add_index :zones, :geom, using: :gist

    create_table :search_zones do |t|
      t.references :search_preference, null: false, foreign_key: true
      t.references :zone, null: false, foreign_key: true
      t.timestamps
    end

    add_index :search_zones, [:search_preference_id, :zone_id], unique: true
  end
end
