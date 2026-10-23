require "test_helper"

class BrandIdentityTest < ActionDispatch::IntegrationTest
  test "authentication and public tour share Timbre install metadata" do
    [new_user_session_path, tour_path].each do |path|
      get path
      assert_response :success
      assert_select "title", text: /Timbre/
      assert_select "meta[name='theme-color'][content='#173F36']"
      assert_select "link[rel='manifest'][href='/manifest.json']"
      assert_select "link[rel='apple-touch-icon'][href='/branding/apple-touch-icon.png']"
      assert_select "link[rel='icon'][href='/branding/favicon.svg']"
      assert_not_includes response.body, "Rental Scout"
    end
  end

  test "install icons exist and use separate standard and maskable assets" do
    manifest = JSON.parse(Rails.root.join("public/manifest.json").read)
    assert_equal "Timbre", manifest.fetch("name")
    assert_equal "#173F36", manifest.fetch("theme_color")
    assert_equal %w[any maskable], manifest.fetch("icons").map { |icon| icon.fetch("purpose") }.uniq.sort
    manifest.fetch("icons").each do |icon|
      assert Rails.root.join("public", icon.fetch("src").delete_prefix("/")).file?
    end
  end
end
