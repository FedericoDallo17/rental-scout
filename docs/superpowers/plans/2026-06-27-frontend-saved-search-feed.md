# Frontend Saved Search Feed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the minimal listings page into a polished, marketplace-style saved-search feed with a left search sidebar and a results-first listings grid.

**Architecture:** Keep the app server-rendered in Rails. Use `SearchPreference` as the first saved-search object for the frontend, with one selected search controlling which listings appear in the main grid. Add only enough matching/filtering logic to support the personalized feed concept without redesigning the broader product domain.

**Tech Stack:** Rails 8, ERB, server-rendered UI, Minitest, PostgreSQL, existing scraper/listing models

## Global Constraints

- Use a Rails monorepo as the default architecture.
- The portal is the primary user-facing surface.
- The scraper/job pipeline is the primary backend engine.
- The UI should be server-rendered first.
- Keep the default Rails Minitest test framework enabled.
- Keep structure simple.
- Do not over-automate.
- The frontend should feel premium and consumer-friendly.
- Preserve a marketplace-first browsing experience.
- Center the UX around saved searches.
- Make the selected search feel like the active browsing context.
- Keep listing discovery easy to scan and revisit repeatedly.

---

## File Structure Map

- `app/controllers/listings_controller.rb` — selects active saved search, loads sidebar searches, and scopes the feed listings
- `app/models/search_preference.rb` — exposes minimal feed-selection helpers used by the controller/view
- `app/models/listing.rb` — exposes minimal query helpers for feed filtering and card rendering
- `app/views/listings/index.html.erb` — main marketplace page with saved-search sidebar and listings grid
- `app/assets/stylesheets/application.css` — polished marketplace layout, sidebar, and cards
- `config/routes.rb` — keeps `/` and `/listings` as the feed entrypoint using query params for selected search
- `db/seeds.rb` — provides local demo searches aligned with the personalized-feed concept
- `test/controllers/listings_controller_test.rb` — verifies active search selection and filtered feed behavior
- `test/integration/listings_flow_test.rb` — verifies the polished page structure and saved-search navigation
- `test/models/listing_test.rb` — verifies any new feed-scope query helpers

### Task 1: Add saved-search feed selection behavior

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/app/controllers/listings_controller.rb`
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/app/models/search_preference.rb`
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/app/models/listing.rb`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/controllers/listings_controller_test.rb`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/models/listing_test.rb`

**Interfaces:**
- Consumes: existing `SearchPreference`, `Listing`, `ListingSource`
- Produces:
  - `ListingsController#index` assigns `@searches`, `@active_search`, and `@listings`
  - `Listing.for_search_feed(search_preference)` returns scoped listings for the selected search

- [ ] **Step 1: Write the failing model test for feed scoping**

```ruby
test "for_search_feed scopes listings by location query" do
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  matching = Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
  Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
  search = SearchPreference.create!(name: "Pocitos search", location_query: "Pocitos")

  assert_equal [matching], Listing.for_search_feed(search).to_a
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/listing_test.rb`
Expected: FAIL because `Listing.for_search_feed` does not exist yet

- [ ] **Step 3: Write the failing controller test for active search selection**

```ruby
test "uses the selected saved search to filter the feed" do
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
```

- [ ] **Step 4: Run test to verify it fails**

Run: `bin/rails test test/controllers/listings_controller_test.rb`
Expected: FAIL because the controller does not yet scope by selected search

- [ ] **Step 5: Write minimal model/controller implementation**

```ruby
class SearchPreference < ApplicationRecord
  has_many :notification_events, dependent: :restrict_with_exception

  validates :name, :location_query, presence: true

  scope :ordered_for_sidebar, -> { order(:name) }
end
```

```ruby
class Listing < ApplicationRecord
  # existing associations/validations...

  scope :recent_first, -> { order(created_at: :desc) }

  def self.for_search_feed(search_preference)
    return recent_first unless search_preference

    where(location_text: search_preference.location_query).recent_first
  end
end
```

```ruby
class ListingsController < ApplicationController
  def index
    @searches = SearchPreference.ordered_for_sidebar
    @active_search = @searches.find_by(id: params[:search_id]) || @searches.first
    @listings = Listing.includes(:listing_source).for_search_feed(@active_search)
  end
end
```

- [ ] **Step 6: Run focused tests to verify they pass**

Run: `bin/rails test test/models/listing_test.rb test/controllers/listings_controller_test.rb`
Expected: PASS


### Task 2: Build the saved-search sidebar and marketplace layout

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/app/views/listings/index.html.erb`
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/app/assets/stylesheets/application.css`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/integration/listings_flow_test.rb`

**Interfaces:**
- Consumes: `@searches`, `@active_search`, `@listings`
- Produces: a sidebar + results-grid page structure with balanced listing cards

- [ ] **Step 1: Write the failing integration test for sidebar and active search UI**

```ruby
test "homepage shows saved searches sidebar and listings grid" do
  SearchPreference.create!(name: "Pocitos", location_query: "Pocitos")

  get root_url

  assert_response :success
  assert_includes response.body, "Saved searches"
  assert_includes response.body, "Pocitos"
  assert_includes response.body, "Scraped Apartments"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/listings_flow_test.rb`
Expected: FAIL because the current page does not show the sidebar structure

- [ ] **Step 3: Write the minimal view structure**

```erb
<div class="feed-layout">
  <aside class="search-sidebar">
    <h2>Saved searches</h2>
    <nav>
      <% @searches.each do |search| %>
        <%= link_to search.name, listings_path(search_id: search.id), class: ["search-link", ("search-link--active" if search == @active_search)] %>
      <% end %>
    </nav>
  </aside>

  <main class="feed-main">
    <header class="feed-header">
      <h1>Scraped Apartments</h1>
      <% if @active_search %>
        <p><%= @active_search.name %></p>
      <% end %>
    </header>

    <section class="listings-grid">
      <% @listings.each do |listing| %>
        <article class="listing-card">
          <div class="listing-card__image">Photo</div>
          <div class="listing-card__body">
            <p class="listing-card__price"><%= number_to_currency(listing.price_cents.to_i / 100.0, unit: "$", precision: 0) if listing.price_cents %></p>
            <h2><%= listing.title %></h2>
            <p><%= listing.location_text %></p>
            <p>m²: <%= listing.square_meters %></p>
            <p>Source: <%= listing.listing_source.name %></p>
            <p><%= listing.canonical_url %></p>
          </div>
        </article>
      <% end %>
    </section>
  </main>
</div>
```

- [ ] **Step 4: Add minimal polished CSS**

```css
.feed-layout { display: grid; grid-template-columns: 280px 1fr; gap: 2rem; padding: 2rem; }
.search-sidebar { background: #fff; border-right: 1px solid #e7e7e7; padding-right: 1.5rem; }
.search-link { display: block; padding: 0.75rem 1rem; border-radius: 12px; color: #222; text-decoration: none; }
.search-link--active { background: #f4f1ea; font-weight: 600; }
.listings-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1.25rem; }
.listing-card { background: #fff; border: 1px solid #ece8df; border-radius: 18px; overflow: hidden; }
.listing-card__image { height: 180px; background: linear-gradient(135deg, #ddd, #f3f3f3); display:flex; align-items:center; justify-content:center; }
.listing-card__body { padding: 1rem; }
.listing-card__price { font-weight: 700; }
```

- [ ] **Step 5: Run integration test to verify it passes**

Run: `bin/rails test test/integration/listings_flow_test.rb`
Expected: PASS


### Task 3: Seed realistic demo searches and verify end-to-end behavior

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/db/seeds.rb`
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/test/controllers/listings_controller_test.rb`
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/test/integration/listings_flow_test.rb`

**Interfaces:**
- Consumes: saved-search feed UI from Tasks 1-2
- Produces: locally usable demo searches and stronger end-to-end confidence

- [ ] **Step 1: Write the failing integration test for default active search behavior**

```ruby
test "root defaults to the first saved search feed" do
  SearchPreference.create!(name: "Centro", location_query: "Centro")
  SearchPreference.create!(name: "Pocitos", location_query: "Pocitos")

  get root_url

  assert_response :success
  assert_includes response.body, "Centro"
end
```

- [ ] **Step 2: Run test to verify current behavior fails or is incomplete**

Run: `bin/rails test test/integration/listings_flow_test.rb`
Expected: FAIL or reveal missing deterministic ordering/seed assumptions

- [ ] **Step 3: Add minimal seeds for demo searches**

```ruby
unless Rails.env.production?
  ListingSource.find_or_create_by!(adapter_key: "mock_source") { |source| source.name = "Mock Source" }

  [
    { name: "Pocitos", location_query: "Pocitos" },
    { name: "Centro", location_query: "Centro" },
    { name: "Carrasco", location_query: "Carrasco" }
  ].each do |attrs|
    SearchPreference.find_or_create_by!(name: attrs[:name]) do |search|
      search.location_query = attrs[:location_query]
    end
  end
end
```

- [ ] **Step 4: Ensure ordering is deterministic and rerun focused tests**

Run: `bin/rails test test/controllers/listings_controller_test.rb test/integration/listings_flow_test.rb`
Expected: PASS

- [ ] **Step 5: Run full verification**

Run: `bin/rails test && bin/rails zeitwerk:check`
Expected: all tests pass and Zeitwerk reports `All is good!`

## Self-Review

### Spec coverage
- Saved-search sidebar: covered by Tasks 1-2.
- Listings-first main area: covered by Task 2.
- Personalized feed behavior: covered by Tasks 1 and 3.
- Balanced cards: covered by Task 2.
- Premium marketplace feel: primarily implemented through Task 2 layout/CSS.

### Placeholder scan
- No unresolved TODO/TBD placeholders in the implementation steps.
- Code examples are concrete and tied to exact files.

### Type consistency
- `Listing.for_search_feed(search_preference)` is referenced consistently.
- Controller instance variables remain `@searches`, `@active_search`, and `@listings` throughout the plan.
