require "test_helper"

class SearchZoneTest < ActiveSupport::TestCase
  test "enforces uniqueness per search and zone" do
    user = User.create!(first_name: "Search", last_name: "Owner", email: "zone-owner@example.com", password: "password123", password_confirmation: "password123")
    zone = Zone.create!(name: "Pocitos", slug: "pocitos", aliases: ["pocitos"], geom: Zone.polygon_from_coordinates([[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]))
    search = user.search_preferences.build(name: "Coast", location_query: "legacy")
    search.search_zones.build(zone: zone)
    search.save!

    duplicate = SearchZone.new(search_preference: search, zone: zone)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:zone_id], "has already been taken"
  end
end
