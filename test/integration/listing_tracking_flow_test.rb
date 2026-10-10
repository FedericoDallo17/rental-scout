require "test_helper"

class ListingTrackingFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_push_test_user!
    @source = ListingSource.create!(name: "Tracked source", adapter_key: "tracked_source")
    @listing = Listing.create!(listing_source: @source, title: "Apartment to follow", canonical_url: "https://example.test/follow", external_id: "follow", location_text: "Pocitos", in_scope: true)
    sign_in @user
  end

  test "favorite contact visit and rejection are independent and editable" do
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { favorite: "1" } }
    track = @user.listing_tracks.sole
    assert track.favorite?
    assert_redirected_to listing_tracks_path

    patch listing_track_path(track), params: { listing_track: { contacted_on: "2026-10-01", visited_on: "2026-10-02", rejected_on: "2026-10-03" } }
    assert_equal Date.new(2026, 10, 1), track.reload.contacted_on
    assert_equal Date.new(2026, 10, 2), track.visited_on
    assert_equal Date.new(2026, 10, 3), track.rejected_on

    patch listing_track_path(track), params: { listing_track: { favorite: "0", rejected_on: "" } }
    assert_not track.reload.favorite?
    assert_nil track.rejected_on
    assert_equal Date.new(2026, 10, 1), track.contacted_on

    get listing_tracks_path(status: "contacted")
    assert_response :success
    assert_includes response.body, @listing.title
    get listing_tracks_path(status: "favorites")
    assert_not_includes response.body, @listing.title
  end

  test "tracking creation is idempotent including a reingested apartment" do
    2.times do
      post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { favorite: "1" } }
      assert_response :see_other
    end
    assert_equal 1, @user.listing_tracks.count
    track = @user.listing_tracks.sole
    @listing.destroy!
    replacement = Listing.create!(listing_source: @source, title: "Republished apartment", canonical_url: "https://example.test/follow-new", external_id: "follow")
    post listing_tracks_path, params: { listing_id: replacement.id, listing_track: { contacted_on: "2026-10-01" } }
    assert_response :see_other
    assert_equal 1, @user.listing_tracks.count
    assert_equal replacement.id, track.reload.listing_id
    assert track.favorite?
  end

  test "history is visible without saved searches and after inventory deletion" do
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { visited_on: "2026-10-01" } }
    @listing.destroy!
    get listing_tracks_path(status: "visited")
    assert_response :success
    assert_includes response.body, "Apartment to follow"
    assert_select "a[href='https://example.test/follow']"
    assert_includes response.body, "2026-10-01"
  end

  test "another user cannot read or modify personal history" do
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { favorite: "1" } }
    track = @user.listing_tracks.sole
    sign_out @user
    sign_in create_push_test_user!
    get listing_tracks_path
    assert_not_includes response.body, @listing.title
    patch listing_track_path(track), params: { listing_track: { favorite: "0" } }
    assert_response :not_found
    assert track.reload.favorite?
  end

  test "invalid updates keep history and show errors" do
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { contacted_on: "2026-10-01" } }
    track = @user.listing_tracks.sole
    patch listing_track_path(track), params: { listing_track: { contacted_on: "invalid" } }
    assert_response :unprocessable_entity
    assert_equal Date.new(2026, 10, 1), track.reload.contacted_on
  end

  test "feed renders tracking controls outside the provider link" do
    @user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    get listings_path
    assert_response :success
    assert_select ".listing-card form", count: 1
    assert_select ".listing-card__link form", count: 0
    assert_select "input[name='listing_id'][value='#{@listing.id}']"
  end

  test "feed retains filters and finds history for reingested listings" do
    search = @user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { favorite: "1" } }
    track = @user.listing_tracks.sole
    @listing.destroy!
    replacement = Listing.create!(listing_source: @source, title: "Republished apartment", canonical_url: "https://example.test/follow-new", external_id: "follow", location_text: "Pocitos", in_scope: true)
    get listings_path(search_id: search.id, sort: "price_high")
    assert_select "form[action='#{listing_track_path(track)}'] input[name='listing_track[favorite]'][checked='checked']"
    patch listing_track_path(track), params: { listing_id: replacement.id, return_to: "feed", search_id: search.id, feed_params: { sort: "price_high", include_unknown_area: "0" }, listing_track: { visited_on: "2026-10-01" } }
    assert_redirected_to listings_path(search_id: search.id, sort: "price_high", include_unknown_area: "0")
    assert_equal replacement.id, track.reload.listing_id
    assert track.favorite?
  end

  test "spanish collection renders every status and date label" do
    @user.update!(locale: "es")
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { favorite: "1", contacted_on: "2026-10-01" } }
    get listing_tracks_path
    assert_includes response.body, "Mis apartamentos"
    assert_includes response.body, "Contactados"
    assert_includes response.body, "Visité hoy"
    assert_not_includes response.body, "translation missing"
  end

  test "saved and unsaved cards have distinct accessible field ids" do
    @user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    second = Listing.create!(listing_source: @source, title: "Second apartment", canonical_url: "https://example.test/second-tracking", location_text: "Pocitos", in_scope: true)
    track = @user.listing_tracks.build(id: second.id, favorite: true)
    track.capture_listing(@listing)
    track.save!

    get listings_path

    assert_select ".listing-card", count: 2
    ids = css_select(".listing-tracking input[id]").map { |node| node["id"] }
    assert_equal ids.uniq, ids
    css_select(".listing-tracking label[for]").each do |label|
      assert_select "input[id='#{label['for']}']", count: 1
    end
  end

  test "guests cannot access or create tracking" do
    sign_out @user
    get listing_tracks_path
    assert_redirected_to new_user_session_path
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { favorite: "1" } }
    assert_redirected_to new_user_session_path
    assert_equal 0, ListingTrack.count
  end

  test "turbo creation updates only the feed tracking controls and retains context" do
    search = @user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    post listing_tracks_path, params: { listing_id: @listing.id, return_to: "feed", search_id: search.id, page: "2", feed_params: { sort: "price_high" }, listing_track: { favorite: "1", contacted_on: "2026-10-01" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='listing_tracking_#{@listing.id}']"
    assert_select "input[name='search_id'][value='#{search.id}']"
    assert_select "input[name='page'][value='2']"
    assert_select "input[name='feed_params[sort]'][value='price_high']"
    assert_select "button[name='listing_track[contacted_on]'][value='']", text: "Unmark contacted"
    assert_select "[role='status']", text: "Tracking saved."
  end

  test "turbo unmark removes a card from contacted filter but retains other history" do
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { favorite: "1", contacted_on: "2026-10-01", visited_on: "2026-10-02" } }
    track = @user.listing_tracks.sole
    patch listing_track_path(track), params: { status: "contacted", listing_track: { contacted_on: "" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_select "turbo-stream[action='remove'][target='tracked_apartment_#{track.id}']"
    assert_nil track.reload.contacted_on
    assert track.favorite?
    assert_equal Date.new(2026, 10, 2), track.visited_on
  end

  test "turbo validation renders errors inline without changing saved dates" do
    post listing_tracks_path, params: { listing_id: @listing.id, listing_track: { contacted_on: "2026-10-01" } }
    track = @user.listing_tracks.sole
    patch listing_track_path(track), params: { listing_track: { contacted_on: "invalid" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action='replace'][target='saved_tracking_#{track.id}']"
    assert_select "[role='alert']"
    assert_equal Date.new(2026, 10, 1), track.reload.contacted_on
  end
end
