require "test_helper"

class Scraping::ListingScopeValidatorTest < ActiveSupport::TestCase
  test "marks montevideo rentals as in scope" do
    result = Scraping::ListingScopeValidator.new.call(attributes: {
      operation_type: "alquiler",
      source_city: "Montevideo",
      property_type: "apartamento"
    })

    assert_equal true, result[:in_scope]
    assert_nil result[:scope_rejection_reason]
  end

  test "rejects listings outside montevideo" do
    result = Scraping::ListingScopeValidator.new.call(attributes: {
      operation_type: "alquiler",
      source_city: "Punta del Este",
      property_type: "apartamento"
    })

    assert_equal false, result[:in_scope]
    assert_equal "outside_montevideo", result[:scope_rejection_reason]
  end
end
