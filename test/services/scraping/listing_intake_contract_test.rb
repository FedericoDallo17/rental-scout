require "test_helper"

class Scraping::ListingIntakeContractTest < ActiveSupport::TestCase
  setup do
    @source = ListingSource.find_or_create_by!(adapter_key: "info_casas_api") do |source|
      source.name = "InfoCasas API"
    end
    @valid_attributes = {
      external_id: "1",
      title: "Apto Centro",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/centro/1",
      source_city: "Montevideo",
      operation_type: "alquiler"
    }
  end

  test "accepts attributes satisfying contract" do
    listing = Scraping::ListingIntake.new.call(listing_source: @source, attributes: @valid_attributes)

    assert listing.persisted?
    assert listing.in_scope?
  end

  test "persists optional provider detail attributes when present" do
    listing = Scraping::ListingIntake.new.call(
      listing_source: @source,
      attributes: @valid_attributes.merge(
        expenses_cents: 450_000,
        expenses_currency: "UYU",
        parking_spaces: 1,
        property_type: "apartamento"
      )
    )

    assert_equal 450_000, listing.expenses_cents
    assert_equal "UYU", listing.expenses_currency
    assert_equal 1, listing.parking_spaces
    assert_equal "apartamento", listing.property_type
  end

  test "raises naming missing required attributes" do
    error = assert_raises(Scraping::ListingIntake::InvalidAttributesError) do
      Scraping::ListingIntake.new.call(
        listing_source: @source,
        attributes: @valid_attributes.except(:source_city, :operation_type)
      )
    end

    assert_match "source_city", error.message
    assert_match "operation_type", error.message
    assert_match @valid_attributes[:canonical_url], error.message
    assert_equal 0, Listing.count
  end

  test "orchestrator marks source run failed when adapter violates contract" do
    ListingSource.where.not(id: @source.id).update_all(active: false)
    bad_adapter = Object.new
    bad_adapter.define_singleton_method(:fetch_listings) do
      [
        {
          external_id: "1",
          title: "No scope fields",
          canonical_url: "https://example.test/1"
        }
      ]
    end

    original_resolve = Sources::AdapterRegistry.method(:resolve)
    Sources::AdapterRegistry.define_singleton_method(:resolve) { |_source| bad_adapter }

    run = Scraping::RunOrchestrator.new.call
    source_run = run.scraping_source_runs.find_by!(listing_source: @source)

    assert_equal "failed", source_run.status
    assert_match "source_city", source_run.error_message
    assert_equal "completed_with_failures", run.status
    assert_equal 0, Listing.count
  ensure
    Sources::AdapterRegistry.define_singleton_method(:resolve, original_resolve)
  end
end
