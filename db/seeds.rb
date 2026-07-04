# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

unless Rails.env.production?
  ListingSource.find_or_create_by!(adapter_key: "mock_source") do |source|
    source.name = "Mock Source"
  end

  demo_user = User.find_or_create_by!(email: "demo@example.com") do |user|
    user.first_name = "Demo"
    user.last_name = "User"
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  [
    { name: "Pocitos", location_query: "Pocitos" },
    { name: "Centro", location_query: "Centro" },
    { name: "Carrasco", location_query: "Carrasco" }
  ].each do |attrs|
    search = demo_user.search_preferences.find_or_initialize_by(name: attrs[:name])
    search.location_query = attrs[:location_query]
    search.save!
  end
end
