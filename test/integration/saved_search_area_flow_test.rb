require "test_helper"

class SavedSearchAreaFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_push_test_user!
    sign_in @user
  end

  test "surface range persists and filters the feed and notification matches inclusively" do
    post search_preferences_path, params: { search_preference: { name: "Area", location_query: "Pocitos", min_square_meters: "50", max_square_meters: "70", notifications_enabled: "1" } }
    search = @user.search_preferences.sole
    assert_equal 50, search.min_square_meters
    assert_equal 70, search.max_square_meters
    get edit_search_preference_path(search)
    assert_select "input[name='search_preference[min_square_meters]'][value='50']"
    assert_select "input[name='search_preference[max_square_meters]'][value='70']"

    source = ListingSource.create!(name: "Area source", adapter_key: "saved_area_source")
    run = ScrapingRun.create!(status: "succeeded", started_at: Time.current)
    listings = [49, 50, 70, 71, nil].map do |area|
      Listing.create!(listing_source: source, scraping_run: run, title: "Area #{area || 'unknown'}", canonical_url: "https://example.test/area/#{area || 'unknown'}", location_text: "Pocitos", square_meters: area, in_scope: true)
    end
    expected_ids = listings[1..2].map(&:id)
    assert_equal expected_ids.sort, Listing.for_search_feed(search).pluck(:id).sort
    assert_equal expected_ids.sort, Listings::SavedSearchMatches.new([search]).call.listing_ids_by_search_id.fetch(search.id).sort
    events = Notifications::NewListingFanOut.new.call(scraping_run: run)
    assert_equal expected_ids.sort, events.map(&:listing_id).sort

    get listings_path(search_id: search.id)
    assert_select ".listing-card", count: 2

    patch search_preference_path(search), params: { search_preference: { min_square_meters: "", max_square_meters: "" } }
    assert_equal 5, Listing.for_search_feed(search.reload).count
  end

  test "negative fractional nonnumeric and inverted ranges are rejected" do
    [{ min_square_meters: "-1" }, { max_square_meters: "2.5" }, { min_square_meters: "bad" }, { min_square_meters: "70", max_square_meters: "50" }].each do |range|
      post search_preferences_path, params: { search_preference: { name: "Invalid", location_query: "Pocitos" }.merge(range) }
      assert_response :unprocessable_entity
    end
    assert_equal 0, @user.search_preferences.count
  end
end
