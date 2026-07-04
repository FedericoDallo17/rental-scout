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

    owned_search = user.search_preferences.create!(
      name: "Centro",
      location_query: "Centro"
    )

    assert_equal user, owned_search.user
    assert_includes user.search_preferences, owned_search
  end
end
