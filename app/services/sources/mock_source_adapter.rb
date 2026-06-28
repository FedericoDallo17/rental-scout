module Sources
  class MockSourceAdapter
    def fetch_listings
      [{
        external_id: "mock-1",
        title: "Apto Pocitos",
        canonical_url: "https://example.test/listings/mock-1",
        location_text: "Pocitos",
        price_cents: 3200000,
        square_meters: 55
      }]
    end
  end
end
