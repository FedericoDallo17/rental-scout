# User Ownership and Data Scoping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make saved searches belong to the signed-in user and scope the listings dashboard to `current_user` while keeping scraped listings global.

**Architecture:** Add a required `user_id` foreign key to `search_preferences`, model the ownership relationship on `User` and `SearchPreference`, and resolve all listings-page search state from `current_user.search_preferences`. Keep `Listing.for_search_feed(search_preference)` unchanged so personalization remains a derived filter over shared inventory.

**Tech Stack:** Ruby on Rails 8, Devise, Minitest, SQLite/PostgreSQL-backed Active Record migrations

## Global Constraints

- Keep scraped listings global/shared.
- Avoid storing the same house separately per user.
- Make saved searches user-owned now.
- Scope listings-page search selection to the signed-in user.
- Prefer scoped queries like `current_user.something` to enforce boundaries.
- Do not make `Listing`, `ListingSource`, `ScrapingRun`, `SeenListing`, scraper ingestion, or notification events user-owned in this ticket.
- Do not introduce per-user matched-feed records in this ticket.

---

## File Structure

- Create: `db/migrate/20260704110000_add_user_to_search_preferences.rb` — adds `user_id`, backfills local/dev data in the simplest acceptable way, then enforces null/foreign-key/index constraints.
- Modify: `app/models/user.rb` — declares `has_many :search_preferences`.
- Modify: `app/models/search_preference.rb` — declares `belongs_to :user` and validates ownership through the association.
- Modify: `app/controllers/listings_controller.rb` — replaces global search lookups with `current_user.search_preferences.ordered_for_sidebar` and resolves the active search from that scoped relation.
- Modify: `db/seeds.rb` — creates or reuses a single non-production demo user and attaches demo searches to that user.
- Modify: `db/schema.rb` — reflects the migrated schema.
- Create: `test/models/search_preference_test.rb` — covers required ownership and `User` associations.
- Modify: `test/models/listing_test.rb` — updates feed-filter tests to create owned search preferences.
- Modify: `test/controllers/listings_controller_test.rb` — covers sidebar isolation, foreign search-id fallback, per-user default search, and empty state.
- Modify: `test/integration/listings_flow_test.rb` — covers scoped saved-search rendering in the full signed-in flow.
- Modify: `test/config/bootstrap_config_test.rb` — updates seed expectations to the new owned-search model.

### Task 1: Add `SearchPreference` ownership in schema, models, and seeds

**Files:**
- Create: `db/migrate/20260704110000_add_user_to_search_preferences.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/search_preference.rb`
- Modify: `db/seeds.rb`
- Modify: `db/schema.rb`
- Create: `test/models/search_preference_test.rb`
- Test: `test/models/search_preference_test.rb`

**Interfaces:**
- Consumes: `User` from `app/models/user.rb`, `SearchPreference` from `app/models/search_preference.rb`
- Produces: `User#search_preferences`, `SearchPreference#user`, required `search_preferences.user_id: bigint`, non-production seed user `demo@example.com`

- [ ] **Step 1: Write the failing model test for required ownership**

```ruby
# test/models/search_preference_test.rb
require "test_helper"

class SearchPreferenceTest < ActiveSupport::TestCase
  test "requires a user" do
    search_preference = SearchPreference.new(
      name: "Pocitos",
      location_query: "Pocitos"
    )

    assert_not search_preference.valid?
    assert_includes search_preference.errors[:user], "must exist"
  end

  test "belongs to a user through the association" do
    user = User.create!(
      first_name: "Search",
      last_name: "Owner",
      email: "search-owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    owned_search = user.search_preferences.create!(
      name: "Centro",
      location_query: "Centro"
    )

    assert_equal user, owned_search.user
    assert_includes user.search_preferences, owned_search
  end
end
```

- [ ] **Step 2: Run the model test to verify it fails before implementation**

Run: `bin/rails test test/models/search_preference_test.rb`

Expected: FAIL because `SearchPreference` does not yet know about `user` / `user_id`.

- [ ] **Step 3: Add the failing migration test path by generating the migration and implementing the ownership schema**

```ruby
# db/migrate/20260704110000_add_user_to_search_preferences.rb
class AddUserToSearchPreferences < ActiveRecord::Migration[8.0]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  class MigrationSearchPreference < ApplicationRecord
    self.table_name = "search_preferences"
  end

  def up
    add_reference :search_preferences, :user, foreign_key: true, index: true

    default_user = MigrationUser.order(:id).first

    if default_user.present?
      MigrationSearchPreference.where(user_id: nil).update_all(user_id: default_user.id)
    elsif MigrationSearchPreference.exists?
      raise ActiveRecord::IrreversibleMigration, "A user must exist before assigning existing search preferences"
    end

    change_column_null :search_preferences, :user_id, false
  end

  def down
    remove_reference :search_preferences, :user, foreign_key: true, index: true
  end
end
```

- [ ] **Step 4: Implement the ownership associations in the models**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :search_preferences, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
end
```

```ruby
# app/models/search_preference.rb
class SearchPreference < ApplicationRecord
  belongs_to :user

  has_many :notification_events, dependent: :restrict_with_exception

  validates :name, :location_query, presence: true

  scope :ordered_for_sidebar, -> { order(:created_at, :id) }
end
```

- [ ] **Step 5: Update non-production seeds to use a single demo owner**

```ruby
# db/seeds.rb
unless Rails.env.production?
  ListingSource.find_or_create_by!(adapter_key: "mock_source") do |source|
    source.name = "Mock Source"
  end

  demo_user = User.find_or_create_by!(email: "demo@example.com") do |user|
    user.first_name = "Demo"
    user.last_name = "User"
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  [
    { name: "Pocitos", location_query: "Pocitos" },
    { name: "Centro", location_query: "Centro" },
    { name: "Carrasco", location_query: "Carrasco" }
  ].each do |attrs|
    search = demo_user.search_preferences.find_or_initialize_by(name: attrs[:name])
    search.location_query = attrs[:location_query]
    search.save!
  end
end
```

- [ ] **Step 6: Run the migration and refresh the schema**

Run: `bin/rails db:migrate`

Expected: PASS with a new `search_preferences.user_id` column, foreign key, and updated `db/schema.rb`.

- [ ] **Step 7: Run the model test to verify the new ownership rules pass**

Run: `bin/rails test test/models/search_preference_test.rb`

Expected: PASS with 2 runs, 0 failures.

- [ ] **Step 8: Commit Task 1**

```bash
git add db/migrate/20260704110000_add_user_to_search_preferences.rb db/schema.rb app/models/user.rb app/models/search_preference.rb db/seeds.rb test/models/search_preference_test.rb
git commit -m "feat: add user ownership to saved searches"
```

### Task 2: Scope the listings dashboard to `current_user.search_preferences`

**Files:**
- Modify: `app/controllers/listings_controller.rb`
- Modify: `test/controllers/listings_controller_test.rb`
- Modify: `test/integration/listings_flow_test.rb`
- Test: `test/controllers/listings_controller_test.rb`
- Test: `test/integration/listings_flow_test.rb`

**Interfaces:**
- Consumes: `current_user.search_preferences`, `SearchPreference.ordered_for_sidebar`, `Listing.for_search_feed(search_preference)`
- Produces: controller state `@searches`, `@active_search`, `@listings` all derived from the signed-in user’s scoped searches

- [ ] **Step 1: Write the failing controller tests for per-user scoping and foreign-id fallback**

```ruby
# test/controllers/listings_controller_test.rb
test "signed in user only sees their own saved searches in the sidebar" do
  owner = create_user!(email: "owner@example.com")
  other_user = create_user!(email: "other@example.com")
  sign_in owner

  owner.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
  other_user.search_preferences.create!(name: "Centro", location_query: "Centro")

  get listings_path

  assert_response :success
  assert_includes response.body, "Pocitos"
  refute_includes response.body, "Centro"
end

test "signed in user cannot activate another user's saved search" do
  owner = create_user!(email: "scoped@example.com")
  other_user = create_user!(email: "foreign@example.com")
  sign_in owner

  fallback = owner.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
  foreign_search = other_user.search_preferences.create!(name: "Centro", location_query: "Centro")

  get listings_path(search_id: foreign_search.id)

  assert_response :success
  assert_includes response.body, "Browsing <strong>#{fallback.name}</strong>"
  refute_includes response.body, "Browsing <strong>#{foreign_search.name}</strong>"
end
```

- [ ] **Step 2: Write the failing integration test proving the full signed-in flow hides other users’ saved searches**

```ruby
# test/integration/listings_flow_test.rb
test "signed in listings route scopes saved searches to the current user" do
  current_user = create_user!(email: "scoped-flow@example.com")
  other_user = create_user!(email: "hidden-flow@example.com")
  sign_in current_user

  current_user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
  other_user.search_preferences.create!(name: "Centro", location_query: "Centro")

  get listings_url

  assert_response :success
  assert_select "nav.search-sidebar__nav a.search-link .search-link__name", text: "Pocitos"
  assert_select "nav.search-sidebar__nav a.search-link .search-link__name", text: "Centro", count: 0
end
```

- [ ] **Step 3: Run the targeted controller and integration tests to verify they fail first**

Run: `bin/rails test test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb`

Expected: FAIL because the controller still uses global `SearchPreference.ordered_for_sidebar`.

- [ ] **Step 4: Implement the scoped-query controller logic**

```ruby
# app/controllers/listings_controller.rb
class ListingsController < ApplicationController
  def index
    @searches = current_user.search_preferences.ordered_for_sidebar
    @active_search = @searches.find_by(id: params[:search_id]) || @searches.first
    @listings = if @active_search
      Listing.includes(:listing_source).for_search_feed(@active_search)
    else
      Listing.none
    end
  end
end
```

- [ ] **Step 5: Update the existing controller tests to create owned searches instead of global ones**

```ruby
# test/controllers/listings_controller_test.rb
test "signed in user uses the selected saved search to filter the feed" do
  user = create_user!(email: "filters@example.com")
  sign_in user

  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
  Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
  pocitos = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
  user.search_preferences.create!(name: "Centro", location_query: "Centro")

  get listings_path(search_id: pocitos.id)

  assert_response :success
  assert_includes response.body, "Apto Pocitos"
  refute_includes response.body, "Centro Loft"
end
```

- [ ] **Step 6: Update the integration tests to create searches through the signed-in user**

```ruby
# test/integration/listings_flow_test.rb
test "signed in root defaults to the first saved search feed" do
  user = create_user!(email: "root-feed@example.com")
  sign_in user

  user.search_preferences.create!(name: "Centro", location_query: "Centro")
  user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")

  get listings_url

  assert_response :success
  assert_includes response.body, "Centro"
  assert_select ".feed-header__context", text: /Browsing Centro/
  assert_select "nav.search-sidebar__nav a.search-link.search-link--active .search-link__name", text: "Centro"
end
```

- [ ] **Step 7: Run the targeted controller and integration tests to verify they pass**

Run: `bin/rails test test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb`

Expected: PASS with the new scoping tests and the existing feed tests all green.

- [ ] **Step 8: Commit Task 2**

```bash
git add app/controllers/listings_controller.rb test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb
git commit -m "feat: scope listings searches to current user"
```

### Task 3: Update remaining owned-search callers and verify the end-to-end suite

**Files:**
- Modify: `test/models/listing_test.rb`
- Modify: `test/config/bootstrap_config_test.rb`
- Test: `test/models/listing_test.rb`
- Test: `test/config/bootstrap_config_test.rb`
- Test: `test/models/search_preference_test.rb`
- Test: `test/controllers/listings_controller_test.rb`
- Test: `test/integration/listings_flow_test.rb`
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: `User#search_preferences.create!`, `Listing.for_search_feed(search_preference)`, non-production seed user `demo@example.com`
- Produces: a fully updated test suite that no longer relies on global `SearchPreference.create!`

- [ ] **Step 1: Write the failing updates for remaining listing model tests that still create global searches**

```ruby
# test/models/listing_test.rb
test "for_search_feed scopes listings by location query" do
  user = User.create!(
    first_name: "Listing",
    last_name: "Owner",
    email: "listing-owner@example.com",
    password: "password123",
    password_confirmation: "password123"
  )
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  matching = Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
  Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
  search = user.search_preferences.create!(name: "Pocitos search", location_query: "Pocitos")

  assert_equal [matching], Listing.for_search_feed(search).to_a
end
```

- [ ] **Step 2: Update the seed/bootstrap expectation to the demo user ownership model**

```ruby
# test/config/bootstrap_config_test.rb
test "seeds correct demo saved search locations on repeated runs" do
  demo_user = User.create!(
    first_name: "Demo",
    last_name: "User",
    email: "demo@example.com",
    password: "password123",
    password_confirmation: "password123"
  )
  demo_user.search_preferences.create!(name: "Pocitos", location_query: "Wrong")

  load Rails.root.join("db/seeds.rb")

  assert_equal "Pocitos", demo_user.search_preferences.find_by!(name: "Pocitos").location_query
end
```

- [ ] **Step 3: Run the affected model and bootstrap tests to verify any remaining failures are exposed**

Run: `bin/rails test test/models/listing_test.rb test/config/bootstrap_config_test.rb`

Expected: FAIL until all direct `SearchPreference.create!` callers have been updated to pass ownership.

- [ ] **Step 4: Replace every remaining bare `SearchPreference.create!` in touched tests with explicit user-owned creation**

```ruby
# test/models/listing_test.rb
user = User.create!(
  first_name: "Listing",
  last_name: "Owner",
  email: "listing-owner-2@example.com",
  password: "password123",
  password_confirmation: "password123"
)
search = user.search_preferences.create!(
  name: "Pocitos two bedrooms",
  location_query: "pocitos",
  min_price_cents: 1800000,
  max_price_cents: 2400000,
  min_bedrooms: 2
)
```

```ruby
# test/controllers/listings_controller_test.rb and test/integration/listings_flow_test.rb
user = create_user!(email: "example@example.com")
search = user.search_preferences.create!(
  name: "Pocitos",
  location_query: "Pocitos"
)
```

```ruby
# test/config/bootstrap_config_test.rb
demo_user = User.find_by!(email: "demo@example.com")
assert_equal "Pocitos", demo_user.search_preferences.find_by!(name: "Pocitos").location_query
```

Make those explicit substitutions anywhere the touched tests still rely on global search records.

- [ ] **Step 5: Run the focused ownership regression suite**

Run: `bin/rails test test/models/search_preference_test.rb test/models/listing_test.rb test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb test/integration/authentication_flow_test.rb test/config/bootstrap_config_test.rb`

Expected: PASS with all ownership, feed, auth, and seed regressions green.

- [ ] **Step 6: Run the full Rails test suite for final verification**

Run: `bin/rails test`

Expected: PASS with 0 failures and 0 errors.

- [ ] **Step 7: Commit Task 3**

```bash
git add test/models/listing_test.rb test/config/bootstrap_config_test.rb test/models/search_preference_test.rb test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb test/integration/authentication_flow_test.rb
git commit -m "test: cover owned search scoping"
```
