class AddSourceMetadataToZones < ActiveRecord::Migration[8.0]
  def change
    add_column :zones, :source_key, :string
    add_column :zones, :source_url, :string
    add_column :zones, :source_feature_id, :string
    add_index :zones, [ :source_key, :source_feature_id ], unique: true,
      where: "source_key IS NOT NULL AND source_feature_id IS NOT NULL"
  end
end
