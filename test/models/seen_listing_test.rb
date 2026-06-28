require "test_helper"

class SeenListingTest < ActiveSupport::TestCase
  test "is unique per source and external id" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    SeenListing.create!(listing_source: source, external_id: "abc", canonical_url: "https://example.test/1")

    duplicate = SeenListing.new(listing_source: source, external_id: "abc", canonical_url: "https://example.test/1")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "is unique per source and canonical url even when external id differs" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    SeenListing.create!(listing_source: source, external_id: "abc", canonical_url: "https://example.test/1")

    duplicate = SeenListing.new(listing_source: source, external_id: "xyz", canonical_url: "https://example.test/1")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:canonical_url], "has already been taken"
  end
end
