class AddLocationFieldsToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :latitude, :decimal, precision: 10, scale: 6
    add_column :listings, :longitude, :decimal, precision: 10, scale: 6
    add_column :listings, :source_neighborhood, :string
    add_column :listings, :location_resolution_status, :string, null: false, default: "unresolved"
    add_column :listings, :in_scope, :boolean, null: false, default: true
    add_column :listings, :scope_rejection_reason, :string
    add_column :listings, :coordinates, :st_point, geographic: true, srid: 4326

    add_index :listings, :coordinates, using: :gist
    add_index :listings, :location_resolution_status
    add_index :listings, :in_scope
  end
end
