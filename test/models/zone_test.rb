require "test_helper"

class ZoneTest < ActiveSupport::TestCase
  test "requires name slug and geometry" do
    zone = Zone.new(name: "Pocitos", slug: "pocitos")

    assert_not zone.valid?
    assert_includes zone.errors[:geom], "can't be blank"
  end

  test "normalizes aliases before validation" do
    zone = Zone.new(
      name: "Pocitos",
      slug: "pocitos",
      aliases: ["Pocitos", " pocitos nuevo "],
      geom: Zone.polygon_from_coordinates([
        [-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]
      ])
    )

    zone.valid?

    assert_equal ["pocitos", "pocitos nuevo"], zone.aliases
  end
end
