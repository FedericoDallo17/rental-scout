# Devise Auth Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Devise-based user authentication with required user names, an optional stored Pushover user key, a public landing page, and an authenticated-by-default app boundary.

**Architecture:** Keep authentication conventional and session-based. Add Devise for `User` accounts, extend `User` with required `first_name` and `last_name` plus optional `pushover_user_key`, move the current listings experience behind login, and make the root route a small guest-facing landing page while leaving listings, search preferences, and scraper data globally scoped for now.

**Tech Stack:** Rails 8.0, Minitest, Devise, server-rendered ERB views, PostgreSQL

## Global Constraints

- Use Devise.
- Keep the first ticket narrow.
- Protect everything except landing and auth pages.
- Defer ownership and user-scoped scraper data until later.
- Collect required `first_name` and `last_name` at signup.
- Store optional `pushover_user_key` without implementing notification behavior.
- Use TDD: no production code without a failing test first.

---

## File Structure

### Files to create
- `app/models/user.rb` — Devise-backed user model with required names.
- `config/initializers/devise.rb` — Devise configuration.
- `config/locales/devise.en.yml` — Devise default flash/message copy.
- `db/migrate/20260703120000_devise_create_users.rb` — users table with Devise fields plus names and `pushover_user_key`.
- `app/controllers/home_controller.rb` — guest landing page controller.
- `app/views/home/index.html.erb` — public landing page with sign-in/sign-up links.
- `test/models/user_test.rb` — user persistence and validation coverage.
- `test/integration/authentication_flow_test.rb` — guest/authenticated access and auth lifecycle coverage.

### Files to modify
- `Gemfile` — add Devise dependency.
- `config/routes.rb` — add Devise routes, public root, and authenticated app route(s).
- `app/controllers/application_controller.rb` — require authentication by default and permit extra Devise signup parameters.
- `app/views/layouts/application.html.erb` — expose auth-aware navigation and flash area.
- `test/test_helper.rb` — include Devise integration helpers for request/integration tests.
- `test/controllers/listings_controller_test.rb` — convert guest-success expectations into auth redirects and signed-in success coverage.
- `test/integration/listings_flow_test.rb` — update root-route expectations from listings portal to guest landing page.

### Generated-but-reviewed files
- `app/views/devise/registrations/new.html.erb` — only if needed to surface custom signup fields.
- `bin/rails generate devise:install` may propose environment mailer configuration instructions. Apply only the minimum development/test-safe setup required by the app.

## Task 1: Install Devise and create the richer User model

**Files:**
- Modify: `Gemfile`
- Create: `app/models/user.rb`
- Create: `config/initializers/devise.rb`
- Create: `config/locales/devise.en.yml`
- Create: `db/migrate/20260703120000_devise_create_users.rb`
- Test: `test/models/user_test.rb`

**Interfaces:**
- Consumes: Rails model layer and database migrations.
- Produces: `User` model authenticatable by Devise; database schema with unique email, required names, optional `pushover_user_key`, and encrypted password.

- [ ] **Step 1: Write the failing test**

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires unique email and required names" do
    User.create!(
      first_name: "Jane",
      last_name: "Scout",
      email: "owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    duplicate = User.new(
      first_name: "",
      last_name: "",
      email: "owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
    assert_includes duplicate.errors[:first_name], "can't be blank"
    assert_includes duplicate.errors[:last_name], "can't be blank"
  end

  test "stores encrypted password and optional pushover key" do
    user = User.create!(
      first_name: "Ana",
      last_name: "Portal",
      email: "secure@example.com",
      password: "password123",
      password_confirmation: "password123",
      pushover_user_key: "uQiRzpo4DXghDmr9QzzfQu27cmVRsG"
    )

    assert_not_nil user.encrypted_password
    refute_equal "password123", user.encrypted_password
    assert_equal "uQiRzpo4DXghDmr9QzzfQu27cmVRsG", user.pushover_user_key
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/user_test.rb`

Expected: FAIL with `uninitialized constant User`.

- [ ] **Step 3: Write minimal implementation**

```ruby
# Gemfile
gem "devise"
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :first_name, presence: true
  validates :last_name, presence: true
end
```

```ruby
# db/migrate/20260703120000_devise_create_users.rb
class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :pushover_user_key
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
  end
end
```

Also run:

```bash
bundle install && bin/rails generate devise:install
bin/rails db:migrate
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/user_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Gemfile Gemfile.lock app/models/user.rb config/initializers/devise.rb config/locales/devise.en.yml db/migrate/20260703120000_devise_create_users.rb test/models/user_test.rb
git commit -m "feat: add devise user model"
```

## Task 2: Add public landing page and route split

**Files:**
- Create: `app/controllers/home_controller.rb`
- Create: `app/views/home/index.html.erb`
- Modify: `config/routes.rb`
- Test: `test/integration/listings_flow_test.rb`

**Interfaces:**
- Consumes: Devise routes and existing Rails routing/layout pipeline.
- Produces: public `root_path` routed to `HomeController#index`; protected `listings_path` remains available for later auth gating.

- [ ] **Step 1: Write the failing test**

```ruby
require "test_helper"

class ListingsFlowTest < ActionDispatch::IntegrationTest
  test "root shows a public landing page for guests" do
    get root_url

    assert_response :success
    assert_includes response.body, "Rental Scout Lite"
    assert_includes response.body, "Sign in"
    assert_includes response.body, "Create account"
    refute_includes response.body, "Scraped Apartments"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/listings_flow_test.rb:4`

Expected: FAIL because `root_url` still renders the listings portal and does not show the guest landing-page copy.

- [ ] **Step 3: Write minimal implementation**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  root "home#index"
  resources :listings, only: [:index]
end
```

```ruby
# app/controllers/home_controller.rb
class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index], raise: false

  def index
  end
end
```

```erb
<!-- app/views/home/index.html.erb -->
<main>
  <h1>Rental Scout Lite</h1>
  <p>Track rental opportunities with a private authenticated dashboard.</p>
  <nav>
    <%= link_to "Sign in", new_user_session_path %>
    <%= link_to "Create account", new_user_registration_path %>
  </nav>
</main>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/listings_flow_test.rb:4`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb app/controllers/home_controller.rb app/views/home/index.html.erb test/integration/listings_flow_test.rb
git commit -m "feat: add public landing page"
```

## Task 3: Wire Devise routes and authenticated-by-default controller behavior

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `test/test_helper.rb`
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: `User` model and Devise initializer from Task 1.
- Produces: `authenticate_user!` enforced by default; `devise_for :users`; integration tests can use `sign_in(user)`.

- [ ] **Step 1: Write the failing test**

```ruby
require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "guest is redirected to sign in when requesting listings" do
    get listings_url

    assert_redirected_to new_user_session_path
  end

  test "signed in user can access listings" do
    user = User.create!(first_name: "View", last_name: "Only", email: "viewer@example.com", password: "password123", password_confirmation: "password123")
    sign_in user

    get listings_url

    assert_response :success
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: FAIL because guests are not yet redirected and integration helpers are not wired.

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end
```

```ruby
# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/application_controller.rb test/test_helper.rb test/integration/authentication_flow_test.rb
git commit -m "feat: protect app with devise authentication"
```

## Task 4: Permit richer signup fields and support full auth lifecycle coverage

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/devise/registrations/new.html.erb` (only if needed)
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: working Devise routes and `User` model.
- Produces: signup accepts required names and optional `pushover_user_key`; layout exposes auth feedback.

- [ ] **Step 1: Write the failing test**

```ruby
require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "user can sign up sign in and sign out with names and optional pushover key" do
    post user_registration_path, params: {
      user: {
        first_name: "Lara",
        last_name: "Scout",
        email: "new-user@example.com",
        password: "password123",
        password_confirmation: "password123",
        pushover_user_key: "uQiRzpo4DXghDmr9QzzfQu27cmVRsG"
      }
    }

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Signed in successfully"
    assert User.exists?(email: "new-user@example.com", first_name: "Lara", last_name: "Scout", pushover_user_key: "uQiRzpo4DXghDmr9QzzfQu27cmVRsG")

    delete destroy_user_session_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Signed out successfully"

    post user_session_path, params: {
      user: {
        email: "new-user@example.com",
        password: "password123"
      }
    }

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Signed in successfully"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: FAIL because Devise does not yet permit the extra signup parameters, and the app layout does not yet render Devise flash messages.

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :pushover_user_key])
  end
end
```

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "Rental Scout Lite" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  </head>

  <body>
    <header>
      <nav>
        <% if user_signed_in? %>
          <span><%= current_user.email %></span>
          <%= button_to "Sign out", destroy_user_session_path, method: :delete %>
        <% else %>
          <%= link_to "Sign in", new_user_session_path %>
          <%= link_to "Create account", new_user_registration_path %>
        <% end %>
      </nav>
    </header>

    <% flash.each do |key, message| %>
      <p class="flash flash--<%= key %>"><%= message %></p>
    <% end %>

    <%= yield %>
  </body>
</html>
```

If the default Devise registration page does not expose the new fields, generate and customize the registration view to include:

```erb
<div>
  <%= f.label :first_name %><br />
  <%= f.text_field :first_name, autofocus: true, autocomplete: "given-name" %>
</div>

<div>
  <%= f.label :last_name %><br />
  <%= f.text_field :last_name, autocomplete: "family-name" %>
</div>

<div>
  <%= f.label :pushover_user_key %><br />
  <%= f.text_field :pushover_user_key %>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/application_controller.rb app/views/layouts/application.html.erb app/views/devise/registrations/new.html.erb test/integration/authentication_flow_test.rb
git commit -m "feat: support richer devise signup fields"
```

## Task 5: Ensure public pages stay public and auth pages are reachable

**Files:**
- Modify: `app/controllers/home_controller.rb`
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: authenticated-by-default `ApplicationController` from Tasks 3 and 4.
- Produces: guest landing page explicitly skips auth and coexists with Devise pages.

- [ ] **Step 1: Write the failing test**

```ruby
require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "guest can access the landing page and sign in page" do
    get root_url
    assert_response :success

    get new_user_session_url
    assert_response :success
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: FAIL because `HomeController#index` inherits `authenticate_user!` until it is explicitly skipped.

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/controllers/home_controller.rb
class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/home_controller.rb test/integration/authentication_flow_test.rb
git commit -m "fix: allow guest auth entry points"
```

## Task 6: Update existing listings tests for the protected-app behavior

**Files:**
- Modify: `test/controllers/listings_controller_test.rb`
- Modify: `test/integration/listings_flow_test.rb`
- Test: `test/controllers/listings_controller_test.rb`
- Test: `test/integration/listings_flow_test.rb`

**Interfaces:**
- Consumes: auth boundary from Tasks 3–5.
- Produces: existing listings coverage aligned with guest redirects and signed-in success behavior.

- [ ] **Step 1: Write the failing test changes**

```ruby
# test/controllers/listings_controller_test.rb
require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected away from listings" do
    get listings_path

    assert_redirected_to new_user_session_path
  end

  test "signed in user uses the selected saved search to filter the feed" do
    user = User.create!(first_name: "Filter", last_name: "User", email: "filters@example.com", password: "password123", password_confirmation: "password123")
    sign_in user

    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
    pocitos = SearchPreference.create!(name: "Pocitos", location_query: "Pocitos")
    SearchPreference.create!(name: "Centro", location_query: "Centro")

    get listings_path(search_id: pocitos.id)

    assert_response :success
    assert_includes response.body, "Apto Pocitos"
    refute_includes response.body, "Centro Loft"
  end
end
```

```ruby
# test/integration/listings_flow_test.rb
require "test_helper"

class ListingsFlowTest < ActionDispatch::IntegrationTest
  test "signed in user can reach the listings portal from listings route" do
    user = User.create!(first_name: "Portal", last_name: "Viewer", email: "portal@example.com", password: "password123", password_confirmation: "password123")
    sign_in user

    get listings_url

    assert_response :success
    assert_includes response.body, "Scraped Apartments"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb`

Expected: FAIL until the existing guest-success expectations are updated to sign users in where protected access is required.

- [ ] **Step 3: Write minimal implementation**

Update the existing tests so:

```ruby
user = User.create!(first_name: "Reader", last_name: "User", email: "reader@example.com", password: "password123", password_confirmation: "password123")
sign_in user
```

and replace the old root-route portal expectations with the new guest landing-page expectations from Task 2.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb
git commit -m "test: align listings coverage with auth boundary"
```

## Task 7: Run the full test suite and verify the auth foundation end state

**Files:**
- Test: `test/models/user_test.rb`
- Test: `test/integration/authentication_flow_test.rb`
- Test: `test/controllers/listings_controller_test.rb`
- Test: `test/integration/listings_flow_test.rb`
- Test: `test/**/*`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: verified auth foundation ready for later ownership work.

- [ ] **Step 1: Run the focused auth-related suite**

Run: `bin/rails test test/models/user_test.rb test/integration/authentication_flow_test.rb test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb`

Expected: PASS.

- [ ] **Step 2: Run the full test suite**

Run: `bin/rails test`

Expected: PASS with no regressions.

- [ ] **Step 3: Inspect routes for the final shape**

Run: `bin/rails routes`

Expected: output includes `root`, `new_user_session`, `destroy_user_session`, `new_user_registration`, and `listings`.

- [ ] **Step 4: Commit the final verified state**

```bash
git add .
git commit -m "feat: add devise auth foundation"
```

## Self-Review

- Spec coverage check:
  - Devise-based auth foundation: Tasks 1–5.
  - Required names and optional `pushover_user_key`: Tasks 1 and 4.
  - Public landing page: Task 2.
  - Authenticated-by-default app boundary: Tasks 3, 5, and 6.
  - No ownership migration: no task alters `Listing`, `SearchPreference`, or scraper ownership.
  - Registration/login/logout/protected-page tests: Tasks 4–7.
- Placeholder scan: replaced generic “add auth” steps with explicit files, tests, and commands.
- Type consistency check:
  - `User` is the sole auth model across all tasks.
  - `authenticate_user!`, `user_signed_in?`, `current_user`, `new_user_session_path`, `user_registration_path`, and `destroy_user_session_path` are used consistently.
