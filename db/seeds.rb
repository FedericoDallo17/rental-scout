# This file ensures records required to run the application exist in every
# environment except production. It is idempotent and can be run repeatedly.

unless Rails.env.production?
  ListingSource.find_or_create_by!(adapter_key: "mock_source") do |source|
    source.name = "Mock Source"
  end

  ListingSource.find_or_create_by!(adapter_key: "info_casas_api") do |source|
    source.name = "InfoCasas API"
  end

  demo_user = User.find_or_create_by!(email: "demo@example.com") do |user|
    user.first_name = "Demo"
    user.last_name = "User"
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  zone_definitions = {
    "Pocitos" => {
      slug: "pocitos",
      aliases: ["pocitos", "pocitos nuevo"],
      coordinates: [[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]
    },
    "Centro" => {
      slug: "centro",
      aliases: ["centro"],
      coordinates: [[-56.21, -34.92], [-56.17, -34.92], [-56.17, -34.89], [-56.21, -34.89], [-56.21, -34.92]]
    },
    "Carrasco" => {
      slug: "carrasco",
      aliases: ["carrasco", "carrasco norte"],
      coordinates: [[-56.07, -34.91], [-56.01, -34.91], [-56.01, -34.86], [-56.07, -34.86], [-56.07, -34.91]]
    }
  }

  zones = zone_definitions.transform_values do |attrs|
    Zone.find_or_initialize_by(slug: attrs[:slug]).tap do |zone|
      zone.name = zone_definitions.key(attrs)
      zone.aliases = attrs[:aliases]
      zone.geom = Zone.polygon_from_coordinates(attrs[:coordinates])
      zone.active = true
      zone.save!
    end
  end

  {
    "Pocitos" => [zones["Pocitos"]],
    "Centro" => [zones["Centro"]],
    "Carrasco" => [zones["Carrasco"]],
    "Costa Este" => [zones["Pocitos"], zones["Carrasco"]]
  }.each do |name, search_zones|
    search = demo_user.search_preferences.find_or_initialize_by(name: name)
    search.location_query = search_zones.map(&:name).join(", ")
    search.save!
    search.zones = search_zones
  end
end
