require "test_helper"

class Sources::ThirdPartyCallTrackerTest < ActiveSupport::TestCase
  test "records lifetime and per-run calls" do
    source = ListingSource.create!(name: "Tracked Source", adapter_key: "tracked_source")
    run = ScrapingRun.create!(status: "running", started_at: Time.current)
    source_run = run.scraping_source_runs.create!(listing_source: source, status: "running", started_at: Time.current)
    tracker = Sources::ThirdPartyCallTracker.new(listing_source: source, source_run:)

    2.times { tracker.call }

    assert_equal 2, source.reload.third_party_calls_count
    assert_equal 2, source_run.reload.third_party_calls_count
  end
end
