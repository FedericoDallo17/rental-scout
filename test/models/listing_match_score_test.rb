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
    assert_equal ["25% under budget", "2 bedrooms"], result.explanations
    assert_equal "Complete details", result.completeness
  end

  test "price points taper to zero at the maximum" do
    search = SearchPreference.new(max_price_cents: 4_000_000)
    listing = Listing.new(price_cents: 3_500_000)

    result = ListingMatchScore.new(listing, search).result

    assert_equal 50, result.score
    assert_includes result.explanations, "13% under budget"
  end

  test "omits a numeric score when no measured preferences exist" do
    result = ListingMatchScore.new(Listing.new, SearchPreference.new).result

    assert_nil result.score
    assert_empty result.explanations
    assert_equal "Basic details", result.completeness
  end

  test "clamps non-matching inputs to the score bounds" do
    search = SearchPreference.new(max_price_cents: 4_000_000, min_bedrooms: 2)
    listing = Listing.new(price_cents: 5_000_000, bedrooms: -100)

    assert_equal 0, ListingMatchScore.new(listing, search).result.score
  end

  test "localizes score explanations" do
    result = I18n.with_locale(:es) do
      ListingMatchScore.new(Listing.new, SearchPreference.new).result
    end

    assert_empty result.explanations
    assert_equal "Información básica", result.completeness
  end

  test "does not compare prices in a different currency" do
    search = SearchPreference.new(max_price_cents: 4_000_000, price_currency: "UYU")
    listing = Listing.new(price_cents: 900_000, currency: "USD")

    result = ListingMatchScore.new(listing, search).result

    assert_equal 0, result.score
    assert_includes result.explanations, "Price is in another currency"
  end

  test "weights price seventy and bedrooms thirty when both are active" do
    search = SearchPreference.new(max_price_cents: 4_000_000, min_bedrooms: 2)
    listing = Listing.new(price_cents: 3_500_000, currency: "UYU", bedrooms: 2)

    result = ListingMatchScore.new(listing, search).result

    assert_equal 59, result.score
  end

  test "normalizes a bedroom-only preference to the full scale" do
    search = SearchPreference.new(min_bedrooms: 2)
    listing = Listing.new(bedrooms: 3)

    assert_equal 100, ListingMatchScore.new(listing, search).result.score
  end
end
