class AddPriceCurrencyToSearchPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :search_preferences, :price_currency, :string, default: "UYU", null: false
  end
end
