class AddSquareMetersAndExternalIdIndexToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :square_meters, :integer
    add_index :listings, [ :listing_source_id, :external_id ], unique: true, where: "external_id IS NOT NULL"
  end
end
