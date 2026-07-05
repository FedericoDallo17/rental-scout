require "test_helper"

class SearchPreferenceTest < ActiveSupport::TestCase
  test "requires a user" do
    search_preference = SearchPreference.new(
      name: "Pocitos",
      location_query: "Pocitos"
    )

    assert_not search_preference.valid?
    assert_includes search_preference.errors[:user], "must exist"
  end

  test "belongs to a user through the association" do
    user = User.create!(
      first_name: "Search",
      last_name: "Owner",
      email: "search-owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    zone = Zone.create!(
      name: "Centro",
      slug: "centro",
      aliases: ["centro"],
      geom: Zone.polygon_from_coordinates([
        [-56.21, -34.91], [-56.18, -34.91], [-56.18, -34.89], [-56.21, -34.89], [-56.21, -34.91]
      ])
    )

    owned_search = user.search_preferences.build(
      name: "Centro",
      location_query: "Centro"
    )
    owned_search.search_zones.build(zone: zone)

    owned_search.save!

    assert_equal user, owned_search.user
    assert_includes user.search_preferences, owned_search
  end

  test "requires at least one zone once zone search is enabled" do
    user = User.create!(first_name: "Search", last_name: "Owner", email: "search-owner-2@example.com", password: "password123", password_confirmation: "password123")
    search_preference = user.search_preferences.build(name: "Pocitos", location_query: "legacy")

    assert_not search_preference.valid?
    assert_includes search_preference.errors[:zones], "must include at least one zone"
  end
end
