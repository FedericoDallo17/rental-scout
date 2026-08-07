class AddFeedFilterIndexesToListings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_index :listings, [:currency, :price_cents],
      name: "index_listings_feed_currency_price",
      where: "in_scope = TRUE AND price_cents IS NOT NULL",
      algorithm: :concurrently
    add_index :listings, :square_meters,
      name: "index_listings_feed_square_meters",
      where: "in_scope = TRUE AND square_meters > 0",
      algorithm: :concurrently
    add_index :listings, :created_at,
      name: "index_listings_feed_created_at",
      order: :desc,
      where: "in_scope = TRUE",
      algorithm: :concurrently

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_listings_feed_expenses
      ON listings (COALESCE(NULLIF(expenses_currency, ''), currency), expenses_cents)
      WHERE in_scope = TRUE AND expenses_cents IS NOT NULL
    SQL
    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_listings_feed_price_per_m2
      ON listings (currency, (price_cents::numeric / NULLIF(square_meters, 0)))
      WHERE in_scope = TRUE AND price_cents IS NOT NULL AND square_meters > 0
    SQL
  end

  def down
    remove_index :listings, name: "index_listings_feed_currency_price", algorithm: :concurrently
    remove_index :listings, name: "index_listings_feed_square_meters", algorithm: :concurrently
    remove_index :listings, name: "index_listings_feed_created_at", algorithm: :concurrently
    remove_index :listings, name: "index_listings_feed_expenses", algorithm: :concurrently
    remove_index :listings, name: "index_listings_feed_price_per_m2", algorithm: :concurrently
  end
end
