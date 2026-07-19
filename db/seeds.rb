# This file ensures records required to run the application exist in every
# environment except production. It is idempotent and can be run repeatedly.

unless Rails.env.production?
  ListingSource.find_or_create_by!(adapter_key: "info_casas_api") do |source|
    source.name = "InfoCasas API"
  end

  [
    ["remax", "Remax"],
    ["housi", "Housi"],
    ["imperium_inmobiliaria", "Imperium Inmobiliaria"]
  ].each do |adapter_key, name|
    ListingSource.find_or_create_by!(adapter_key:) do |source|
      source.name = name
      source.active = false
    end
  end

  demo_user = User.find_or_create_by!(email: "demo@example.com") do |user|
    user.first_name = "Demo"
    user.last_name = "User"
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  User.where("LOWER(email) = ?", "federico@neocoast.com").update_all(admin: true)

zone_definitions = {
  "Pocitos" => {
    slug: "pocitos",
    aliases: ["pocitos", "pocitos nuevo"],
    coordinates: [[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]
  },
  "Punta Carretas" => {
    slug: "punta-carretas",
    aliases: ["punta carretas"],
    coordinates: [[-56.17, -34.93], [-56.145, -34.93], [-56.145, -34.915], [-56.17, -34.915], [-56.17, -34.93]]
  },
  "Parque Rodó" => {
    slug: "parque-rodo",
    aliases: ["parque rodo", "parque rodó"],
    coordinates: [[-56.18, -34.925], [-56.16, -34.925], [-56.16, -34.905], [-56.18, -34.905], [-56.18, -34.925]]
  },
  "Cordón" => {
    slug: "cordon",
    aliases: ["cordon", "cordón"],
    coordinates: [[-56.19, -34.91], [-56.17, -34.91], [-56.17, -34.895], [-56.19, -34.895], [-56.19, -34.91]]
  },
  "Palermo" => {
    slug: "palermo",
    aliases: ["palermo"],
    coordinates: [[-56.195, -34.92], [-56.18, -34.92], [-56.18, -34.905], [-56.195, -34.905], [-56.195, -34.92]]
  },
  "Centro" => {
    slug: "centro",
    aliases: ["centro"],
    coordinates: [[-56.21, -34.92], [-56.17, -34.92], [-56.17, -34.89], [-56.21, -34.89], [-56.21, -34.92]]
  },
  "Ciudad Vieja" => {
    slug: "ciudad-vieja",
    aliases: ["ciudad vieja"],
    coordinates: [[-56.225, -34.915], [-56.205, -34.915], [-56.205, -34.895], [-56.225, -34.895], [-56.225, -34.915]]
  },
  "Aguada" => {
    slug: "aguada",
    aliases: ["aguada"],
    coordinates: [[-56.205, -34.895], [-56.185, -34.895], [-56.185, -34.875], [-56.205, -34.875], [-56.205, -34.895]]
  },
  "Tres Cruces" => {
    slug: "tres-cruces",
    aliases: ["tres cruces"],
    coordinates: [[-56.175, -34.905], [-56.155, -34.905], [-56.155, -34.885], [-56.175, -34.885], [-56.175, -34.905]]
  },
  "La Blanqueada" => {
    slug: "la-blanqueada",
    aliases: ["la blanqueada"],
    coordinates: [[-56.155, -34.895], [-56.13, -34.895], [-56.13, -34.875], [-56.155, -34.875], [-56.155, -34.895]]
  },
  "Buceo" => {
    slug: "buceo",
    aliases: ["buceo"],
    coordinates: [[-56.145, -34.92], [-56.115, -34.92], [-56.115, -34.895], [-56.145, -34.895], [-56.145, -34.92]]
  },
  "Malvín" => {
    slug: "malvin",
    aliases: ["malvin", "malvín"],
    coordinates: [[-56.125, -34.91], [-56.085, -34.91], [-56.085, -34.885], [-56.125, -34.885], [-56.125, -34.91]]
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
