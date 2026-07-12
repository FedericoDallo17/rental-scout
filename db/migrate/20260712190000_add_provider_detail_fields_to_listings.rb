class AddProviderDetailFieldsToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :expenses_cents, :integer
    add_column :listings, :expenses_currency, :string
    add_column :listings, :parking_spaces, :integer
    add_column :listings, :property_type, :string
  end
end
