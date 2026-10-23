require "test_helper"

class NotificationResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name: "Phone", last_name: "User", email: "phone-results@example.com",
      password: "password123", password_confirmation: "password123"
    )
    @run = ScrapingRun.create!(status: "succeeded", started_at: Time.current)
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    search = @user.search_preferences.create!(name: "Private saved search", location_query: "centro")
    @listing = Listing.create!(
      listing_source: source, scraping_run: @run, title: "Apto Centro",
      canonical_url: "https://example.com/apto-centro"
    )
    NotificationEvent.create!(
      listing: @listing, listing_source: source, search_preference: search,
      event_kind: "new_listing", channel: "pushover", status: "sent",
      idempotency_key: "public-results"
    )
  end

  test "signed notification link shows only public listing details without login" do
    get notification_results_path(token: token_for(@user, @run))

    assert_response :success
    assert_select ".auth-flash", count: 0
    assert_select "h1", text: "Your new matches"
    assert_select "h2", text: @listing.title
    assert_select "a[href='#{@listing.canonical_url}']", text: "Open property"
    assert_not_includes response.body, @user.email
    assert_not_includes response.body, "Private saved search"
  end

  test "invalid notification link is not accessible" do
    get notification_results_path(token: "invalid")

    assert_response :not_found
  end

  test "notification page uses the recipient's language" do
    @user.update!(locale: "es")

    get notification_results_path(token: token_for(@user, @run))

    assert_response :success
    assert_select "html[lang='es']"
    assert_select "h1", text: "Lugares que pueden ser para vos"
    assert_select "a[href='#{@listing.canonical_url}']", text: "Abrir propiedad"
  end

  test "a token cannot expose another user's matches" do
    other_user = User.create!(
      first_name: "Other", last_name: "User", email: "other-results@example.com",
      password: "password123", password_confirmation: "password123"
    )

    get notification_results_path(token: token_for(other_user, @run))

    assert_response :not_found
  end

  private

  def token_for(user, run)
    Rails.application.message_verifier(:notification_results).generate(
      { user_id: user.id, scraping_run_id: run.id, locale: user.locale },
      expires_in: 7.days,
      purpose: :notification_results
    )
  end
end
