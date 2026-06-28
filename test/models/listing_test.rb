require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "requires source and canonical url" do
    listing = Listing.new(title: "Apto")

    assert_not listing.valid?
    assert_includes listing.errors[:listing_source], "must exist"
    assert_includes listing.errors[:canonical_url], "can't be blank"
  end

  test "prevents destroy when notification events reference it" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    listing = Listing.create!(listing_source: source, title: "Apto", canonical_url: "https://example.test/1")
    NotificationEvent.create!(
      listing: listing,
      listing_source: source,
      event_kind: "new_listing",
      status: "sent",
      idempotency_key: "evt-1"
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) do
      listing.destroy
    end
  end

  test "validates external id uniqueness within a source" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    Listing.create!(listing_source: source, title: "Apto 1", canonical_url: "https://example.test/1", external_id: "abc")

    duplicate = Listing.new(listing_source: source, title: "Apto 2", canonical_url: "https://example.test/2", external_id: "abc")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "enforces external id uniqueness at the database layer within a source" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    Listing.create!(listing_source: source, title: "Apto 1", canonical_url: "https://example.test/1", external_id: "abc")

    duplicate = Listing.new(listing_source: source, title: "Apto 2", canonical_url: "https://example.test/2", external_id: "abc")

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end
end
