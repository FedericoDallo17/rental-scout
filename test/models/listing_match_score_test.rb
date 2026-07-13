require "test_helper"

class ListingMatchScoreTest < ActiveSupport::TestCase
  test "rewards affordability bedroom fit and complete details" do
    search = SearchPreference.new(max_price_cents: 4_000_000, min_bedrooms: 1)
    listing = Listing.new(
      price_cents: 3_000_000,
      bedrooms: 2,
      square_meters: 50,
      expenses_cents: 0,
      parking_spaces: 0,
      property_type: "Apartamento"
    )

    result = ListingMatchScore.new(listing, search).result

    assert_equal 100, result.score
    assert_equal ["25% under budget", "2 bedrooms", "Complete details"], result.explanations
  end

  test "price points taper to zero at the maximum" do
    search = SearchPreference.new(max_price_cents: 4_000_000)
    listing = Listing.new(price_cents: 3_500_000)

    result = ListingMatchScore.new(listing, search).result

    assert_equal 45, result.score
    assert_includes result.explanations, "13% under budget"
  end

  test "uses neutral preference points when optional filters are absent" do
    result = ListingMatchScore.new(Listing.new, SearchPreference.new).result

    assert_equal 42, result.score
    assert_equal ["No maximum budget", "Any bedroom count", "Basic details"], result.explanations
  end

  test "clamps non-matching inputs to the score bounds" do
    search = SearchPreference.new(max_price_cents: 4_000_000, min_bedrooms: 2)
    listing = Listing.new(price_cents: 5_000_000, bedrooms: -100)

    assert_equal 3, ListingMatchScore.new(listing, search).result.score
  end

  test "localizes score explanations" do
    result = I18n.with_locale(:es) do
      ListingMatchScore.new(Listing.new, SearchPreference.new).result
    end

    assert_equal ["Sin presupuesto máximo", "Cualquier cantidad de dormitorios", "Información básica"], result.explanations
  end

  test "does not compare prices in a different currency" do
    search = SearchPreference.new(max_price_cents: 4_000_000, price_currency: "UYU")
    listing = Listing.new(price_cents: 900_000, currency: "USD")

    result = ListingMatchScore.new(listing, search).result

    assert_equal 15, result.score
    assert_includes result.explanations, "Price is in another currency"
  end
end
