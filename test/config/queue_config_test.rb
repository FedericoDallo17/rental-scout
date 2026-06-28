require "test_helper"
require "erb"
require "yaml"

class QueueConfigTest < ActiveSupport::TestCase
  test "defines production solid queue settings" do
    config = YAML.safe_load(
      ERB.new(Rails.root.join("config/queue.yml").read).result,
      aliases: true
    )

    assert_equal config.fetch("development"), config.fetch("production")
  end
end
