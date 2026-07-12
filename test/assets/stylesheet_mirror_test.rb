require "test_helper"

# public/stylesheets/application.css is a hand-maintained mirror of the asset
# copy (no Propshaft) — see CLAUDE.md. Any edit must touch both files.
class StylesheetMirrorTest < ActiveSupport::TestCase
  test "public stylesheet is byte-identical to the asset stylesheet" do
    asset  = Rails.root.join("app/assets/stylesheets/application.css")
    mirror = Rails.root.join("public/stylesheets/application.css")

    assert File.exist?(asset), "missing #{asset}"
    assert File.exist?(mirror), "missing #{mirror}"
    assert_equal File.binread(asset), File.binread(mirror),
      "app/assets/stylesheets/application.css and public/stylesheets/application.css " \
      "have diverged — they must be byte-identical (edit both, see CLAUDE.md)"
  end
end
