require "test_helper"

class SearchPreferencesControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected away from new saved search" do
    get new_search_preference_path

    assert_redirected_to new_user_session_path
  end

  test "signed in user sees hybrid workbench search form" do
    user = create_user!(email: "search-form-workbench@example.com")
    create_zone("Pocitos", "pocitos")
    sign_in user

    get new_search_preference_path

    assert_response :success
    assert_select ".search-form-shell"
    assert_select ".search-form-panel"
    assert_select ".search-form-aside", text: /Feed preview/
    assert_select "label", text: "Search name"
    assert_select "label", text: "Min price"
    assert_select "label", text: "Max price"
    assert_select "label", text: "Location note"
    assert_select "label", text: /cents/, count: 0
    assert_select "input[name='search_preference[min_price]']"
    assert_select "input[name='search_preference[max_price]']"
    assert_select ".search-form__zones label", text: /Pocitos/
  end

  test "signed in user creates saved search with zones" do
    user = create_user!(email: "create-search@example.com")
    zone = create_zone("Pocitos", "pocitos")
    sign_in user

    post search_preferences_path, params: {
          search_preference: {
            name: "Pocitos under 40",
            location_query: "Pocitos",
            min_price: "20000",
            max_price: "40000",
            min_bedrooms: "1",
            notifications_enabled: "0",
            zone_ids: [zone.id]
      }
    }

    search = user.search_preferences.find_by!(name: "Pocitos under 40")
    assert_equal ["pocitos"], search.zones.pluck(:slug)
    assert_equal 2_000_000, search.min_price_cents
    assert_equal 4_000_000, search.max_price_cents
    assert_equal 1, search.min_bedrooms
    assert_not search.notifications_enabled
    assert_redirected_to listings_path(search_id: search.id)
  end

  test "signed in user sees validation errors without creating saved search" do
    user = create_user!(email: "invalid-search@example.com")
    sign_in user

    assert_no_difference -> { user.search_preferences.count } do
      post search_preferences_path, params: {
        search_preference: {
          name: "",
          location_query: "",
          zone_ids: []
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "could not be saved"
  end

  test "signed in user edits own saved search" do
    user = create_user!(email: "edit-search@example.com")
    old_zone = create_zone("Centro", "centro")
    new_zone = create_zone("Carrasco", "carrasco")
    search = user.search_preferences.create!(name: "Centro", location_query: "Centro", zones: [old_zone])
    sign_in user

    patch search_preference_path(search), params: {
          search_preference: {
            name: "Carrasco",
            location_query: "Carrasco",
            max_price: "65000",
            min_bedrooms: "2",
            notifications_enabled: "1",
            zone_ids: [new_zone.id]
      }
    }

    search.reload
    assert_equal "Carrasco", search.name
    assert_equal "Carrasco", search.location_query
    assert_equal 6_500_000, search.max_price_cents
    assert_equal 2, search.min_bedrooms
    assert_equal ["carrasco"], search.zones.pluck(:slug)
    assert search.notifications_enabled
    assert_redirected_to listings_path(search_id: search.id)
  end

  test "signed in user cannot edit another user's saved search" do
    owner = create_user!(email: "owner-search@example.com")
    other = create_user!(email: "other-search@example.com")
    foreign_search = other.search_preferences.create!(name: "Centro", location_query: "Centro")
    sign_in owner

    get edit_search_preference_path(foreign_search)

    assert_response :not_found
  end

  test "signed in user deletes own saved search without deleting listings" do
    user = create_user!(email: "delete-search@example.com")
    search = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source_delete_search")
    Listing.create!(listing_source: source, title: "Shared listing", canonical_url: "https://example.test/shared")
    sign_in user

    assert_difference -> { user.search_preferences.count }, -1 do
      assert_no_difference -> { Listing.count } do
        delete search_preference_path(search)
      end
    end

    assert_redirected_to listings_path
  end

  test "signed in user deletes search with notification history by keeping events" do
    user = create_user!(email: "delete-search-events@example.com")
    search = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source_delete_search_events")
    listing = Listing.create!(listing_source: source, title: "Shared listing", canonical_url: "https://example.test/shared-events")
    event = NotificationEvent.create!(
      listing: listing,
      listing_source: source,
      search_preference: search,
      event_kind: "new_listing",
      status: "pending",
      idempotency_key: "delete-search-events"
    )
    sign_in user

    assert_difference -> { user.search_preferences.count }, -1 do
      assert_no_difference -> { NotificationEvent.count } do
        delete search_preference_path(search)
      end
    end

    assert_nil event.reload.search_preference_id
    assert_redirected_to listings_path
  end

  test "listings sidebar links to new and edit saved search flows" do
    user = create_user!(email: "sidebar-search-actions@example.com")
    search = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    sign_in user

    get listings_path

    assert_response :success
    assert_select "a[href='#{new_search_preference_path}']", text: "New search"
    assert_select "a[href='#{edit_search_preference_path(search)}']", text: "Edit"
  end

  private

  def create_user!(email:)
    User.create!(
      first_name: "Test",
      last_name: "User",
      email: email,
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def create_zone(name, slug)
    Zone.create!(
      name: name,
      slug: slug,
      aliases: [slug],
      geom: Zone.polygon_from_coordinates([
        [-56.17, -34.92],
        [-56.14, -34.92],
        [-56.14, -34.89],
        [-56.17, -34.89],
        [-56.17, -34.92]
      ])
    )
  end
end
