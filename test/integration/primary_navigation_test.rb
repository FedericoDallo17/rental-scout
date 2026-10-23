require "test_helper"

class PrimaryNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(first_name: "Nav", last_name: "Tester", email: "nav-timbre@example.test",
      password: "password123", password_confirmation: "password123", locale: "es")
    sign_in @user
  end

  test "all primary destinations are directly available on desktop and mobile" do
    [listings_path, listing_tracks_path, scraping_runs_path, edit_notification_settings_path].each do |path|
      get path
      assert_response :success
      [".app-primary-navigation", ".mobile-navigation"].each do |navigation|
        assert_select "#{navigation} a", count: 4
        assert_select "#{navigation} a[href='#{listings_path}']", text: "Resultados"
        assert_select "#{navigation} a[href='#{path}'][aria-current='page']", count: 1
        assert_select "#{navigation} a[aria-current='page']", count: 1
      end
      assert_select ".app-header a[href='#{tour_path}']", count: 0
    end
  end

  test "Results stays active for root, filtering and search editing" do
    search = @user.search_preferences.create!(name: "Centro", location_query: "centro")
    [root_path, listings_path(sort: "price_low"), edit_search_preference_path(search)].each do |path|
      get path
      assert_response :success
      assert_select ".app-primary-navigation a[href='#{listings_path}'][aria-current='page']", text: "Resultados"
      assert_select ".mobile-navigation a[href='#{listings_path}'][aria-current='page']", text: "Resultados"
    end
  end

  test "admin screens do not mark personal Chimes as current" do
    @user.update!(admin: true)
    get admin_root_path
    assert_response :success
    assert_select ".app-header a[href='#{admin_root_path}'][aria-current='page']"
    assert_select ".app-primary-navigation a[aria-current]", count: 0
    assert_select ".mobile-navigation a[aria-current]", count: 0
    assert_select "#location-quality-heading"
  end
end
