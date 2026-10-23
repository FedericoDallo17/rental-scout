require "test_helper"

class ToursControllerTest < ActionDispatch::IntegrationTest
  test "recruiters can explore sample features without signing in" do
    get tour_path
    assert_response :success
    assert_select "[data-tour-panel]", count: 5
    assert_select "[data-tour-budget]"
    assert_select "[data-tour-favorite]", count: 3
    assert_select "[data-tour-alert]"
    assert_select "a[href=?]", new_user_registration_path
    assert_includes response.body, "Fictional listings"
    assert_select "form", count: 4 # language controls in intro and journey only
    assert_select "[data-tour-entrance][hidden]" # progressive enhancement: no JS gate
    assert_select "[data-timbre-trigger='manual'] [data-part='leaf']"
    assert_select "button[data-tour-enter]"
    assert_select "button[data-tour-skip]"
    assert_select "main[data-portfolio-tour]:not([hidden])"
  end

  test "tour follows guest language preference" do
    get tour_path, headers: { "Accept-Language" => "es-UY" }
    assert_response :success
    assert_select "html[lang=es]"
    assert_includes response.body, "Recorrido interactivo"
    assert_not_includes response.body, "Translation missing"
  end

  test "tour is discoverable from sign in while real features stay private" do
    get new_user_session_path
    assert_select "a[href=?]", tour_path
    get listings_path
    assert_redirected_to new_user_session_path
    post listing_tracks_path, params: { listing_track: { favorite: true } }
    assert_redirected_to new_user_session_path
  end
end
