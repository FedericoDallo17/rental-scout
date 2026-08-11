require "test_helper"

class ServiceWorkersControllerTest < ActionDispatch::IntegrationTest
  test "serves a root-scoped service worker without long-lived caching" do
    get "/service-worker.js"

    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "self.addEventListener(\"push\""
    assert_includes response.body, "clients.openWindow"
  end
end
