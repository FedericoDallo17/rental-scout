module Sources
  class ThirdPartyCallTracker
    def initialize(listing_source:, source_run: nil)
      @listing_source = listing_source
      @source_run = source_run
    end

    def call
      listing_source.increment!(:third_party_calls_count)
      source_run&.increment!(:third_party_calls_count)
    end

    private

    attr_reader :listing_source, :source_run
  end
end
