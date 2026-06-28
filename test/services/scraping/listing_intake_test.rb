require "test_helper"

class Scraping::ListingIntakeTest < ActiveSupport::TestCase
  test "does not create duplicate listing for same source and external id" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    attrs = { title: "Apto Pocitos", canonical_url: "https://example.test/a", external_id: "1" }

    intake = Scraping::ListingIntake.new
    first = intake.call(listing_source: source, attributes: attrs)
    second = intake.call(listing_source: source, attributes: attrs)

    assert_equal first.id, second.id
    assert_equal 1, Listing.count
  end

  test "reuses the existing listing when canonical url stays stable and external id changes" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    intake = Scraping::ListingIntake.new

    first = intake.call(
      listing_source: source,
      attributes: { title: "Apto Pocitos", canonical_url: "https://example.test/a", external_id: "1" }
    )

    second = intake.call(
      listing_source: source,
      attributes: { title: "Apto Pocitos", canonical_url: "https://example.test/a", external_id: "2" }
    )

    assert_equal first.id, second.id
    assert_equal "2", second.external_id
    assert_equal 1, Listing.count
    assert_equal 1, SeenListing.count
    assert_equal "2", SeenListing.last.external_id
  end

  test "preserves the first scraping run provenance on re-seen listings" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    first_run = ScrapingRun.create!(status: "succeeded", started_at: Time.current)
    second_run = ScrapingRun.create!(status: "succeeded", started_at: Time.current)
    intake = Scraping::ListingIntake.new

    listing = intake.call(
      listing_source: source,
      attributes: { title: "Apto Pocitos", canonical_url: "https://example.test/a", external_id: "1" },
      scraping_run: first_run
    )

    intake.call(
      listing_source: source,
      attributes: { title: "Apto Pocitos", canonical_url: "https://example.test/a", external_id: "1" },
      scraping_run: second_run
    )

    assert_equal first_run.id, listing.reload.scraping_run_id
    assert_equal first_run.id, SeenListing.last.scraping_run_id
  end

  test "recovers from a listing uniqueness race by loading the canonical record" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    intake = Scraping::ListingIntake.new
    attributes = { title: "Apto Pocitos", canonical_url: "https://example.test/a", external_id: "1" }
    concurrent_listing = Listing.create!(listing_source: source, **attributes, raw_payload: attributes)
    find_listing_calls = 0
    racing_listing = Listing.new(listing_source: source)
    original_new = Listing.method(:new)
    original_save = racing_listing.method(:save!)

    intake.define_singleton_method(:find_listing) do |listing_source:, attributes:|
      find_listing_calls += 1
      find_listing_calls == 1 ? nil : concurrent_listing
    end

    racing_listing.define_singleton_method(:save!) do
      raise ActiveRecord::RecordNotUnique, "duplicate key"
    end

    listing = nil

    begin
      Listing.define_singleton_method(:new) { |*| racing_listing }
      listing = intake.call(listing_source: source, attributes: attributes)
    ensure
      Listing.define_singleton_method(:new, original_new)
      racing_listing.define_singleton_method(:save!, original_save)
    end

    assert_equal concurrent_listing.id, listing.id
    assert_equal 1, Listing.count
    assert_equal 1, SeenListing.count
    assert_equal concurrent_listing.id, SeenListing.last.listing_id
  end

  test "recovers from a seen listing uniqueness race without changing first seen provenance" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    listing = Listing.create!(
      listing_source: source,
      title: "Apto Pocitos",
      canonical_url: "https://example.test/a",
      external_id: "1"
    )
    first_run = ScrapingRun.create!(status: "succeeded", started_at: 2.hours.ago)
    second_run = ScrapingRun.create!(status: "succeeded", started_at: Time.current)
    intake = Scraping::ListingIntake.new
    attributes = { title: "Apto Pocitos", canonical_url: listing.canonical_url, external_id: listing.external_id }
    prior_last_seen_at = 2.hours.ago.change(usec: 0)
    concurrent_seen_listing = SeenListing.create!(
      listing_source: source,
      listing: listing,
      scraping_run: first_run,
      external_id: attributes[:external_id],
      canonical_url: attributes[:canonical_url],
      first_seen_at: 1.day.ago,
      last_seen_at: prior_last_seen_at
    )
    find_seen_listing_calls = 0
    racing_seen_listing = SeenListing.new(listing_source: source)
    original_new = SeenListing.method(:new)
    original_save = racing_seen_listing.method(:save!)

    intake.define_singleton_method(:find_seen_listing) do |listing_source:, attributes:|
      find_seen_listing_calls += 1
      find_seen_listing_calls == 1 ? nil : concurrent_seen_listing.reload
    end

    racing_seen_listing.define_singleton_method(:save!) do
      raise ActiveRecord::RecordNotUnique, "duplicate key"
    end

    begin
      SeenListing.define_singleton_method(:new) { |*| racing_seen_listing }
      intake.call(listing_source: source, attributes: attributes, scraping_run: second_run)
    ensure
      SeenListing.define_singleton_method(:new, original_new)
      racing_seen_listing.define_singleton_method(:save!, original_save)
    end

    seen_listing = SeenListing.last
    assert_equal 1, SeenListing.count
    assert_equal listing.id, seen_listing.listing_id
    assert_equal first_run.id, seen_listing.scraping_run_id
    assert_operator seen_listing.last_seen_at, :>, prior_last_seen_at
  end

  test "persists normalized adapter attributes without intake translation" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    intake = Scraping::ListingIntake.new
    attributes = {
      title: "Apto Pocitos",
      canonical_url: "https://example.test/a",
      external_id: "1",
      location_text: "Pocitos",
      price_cents: 3_200_000,
      square_meters: 55
    }

    listing = intake.call(listing_source: source, attributes: attributes)

    assert_equal "Pocitos", listing.location_text
    assert_equal 55, listing.square_meters
    assert_equal attributes, listing.raw_payload.symbolize_keys.slice(*attributes.keys)
  end
end
