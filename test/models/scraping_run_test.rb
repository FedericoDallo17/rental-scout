require "test_helper"

class ScrapingRunTest < ActiveSupport::TestCase
  test "close abandoned only fails stale running records" do
    stale = ScrapingRun.create!(status: "running", started_at: 3.hours.ago)
    active = ScrapingRun.create!(status: "running", started_at: 10.minutes.ago)
    completed = ScrapingRun.create!(status: "succeeded", started_at: 3.hours.ago)

    assert_equal 1, ScrapingRun.close_abandoned!

    assert_equal "failed", stale.reload.status
    assert_equal "running", active.reload.status
    assert_equal "succeeded", completed.reload.status
  end
end
