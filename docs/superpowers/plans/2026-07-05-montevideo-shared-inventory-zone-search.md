# Montevideo Shared Inventory and Zone Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Rental Scout Lite from source-driven location filtering to a shared Montevideo rental inventory with internal zone-based search powered by PostGIS.

**Architecture:** Keep the existing scraper orchestration and shared `listings` inventory, but broaden source acquisition to Montevideo-wide rentals and move zone filtering into application-owned geography tables. Introduce PostGIS-backed zones plus search-to-zone associations, persist listing coordinates and resolution status, and resolve feed membership at read time using spatial matching first and alias fallback second.

**Tech Stack:** Rails 8, PostgreSQL, PostGIS, Active Record, Minitest, Devise, Net::HTTP

## Global Constraints

- Inventory scope is Montevideo rentals only.
- Third-party sources are inventory providers; our app owns search semantics.
- Saved searches target multiple named zones with OR semantics.
- Spatial matching is authoritative when coordinates exist.
- Fallback matching uses source neighborhood/location metadata only when coordinates are missing.
- Unresolved listings stay stored and must not falsely match zone-based searches.
- Custom user-drawn polygons are explicitly deferred to follow-up work.
- Read-time matching ships first; precomputed listing-to-search matches are follow-up work.
- Follow TDD for every task.

---

## Planned File Structure

- `Gemfile` — add PostGIS adapter dependencies.
- `config/database.yml` — switch the primary adapter to the PostGIS adapter.
- `db/migrate/*_enable_postgis_and_add_zone_tables.rb` — enable PostGIS and create internal geography tables.
- `db/migrate/*_add_location_fields_to_listings.rb` — add listing coordinates, point geometry, boundary fields, and resolution status.
- `db/schema.rb` — updated schema after migrations.
- `app/models/zone.rb` — internal named geography model.
- `app/models/search_preference.rb` — zone associations and updated validations.
- `app/models/search_zone.rb` — join model between saved searches and zones.
- `app/models/listing.rb` — zone-aware feed filtering and location scopes.
- `app/services/scraping/listing_scope_validator.rb` — Montevideo rental boundary validation.
- `app/services/scraping/listing_geometry_builder.rb` — normalize coordinates into canonical point geometry and resolution state.
- `app/services/sources/info_casas_api_adapter.rb` — broaden source acquisition to Montevideo-wide inventory and expose coordinates plus metadata.
- `db/seeds.rb` — seed a curated Montevideo zone set and associate demo searches with zones.
- `test/models/zone_test.rb` — zone validation coverage.
- `test/models/search_zone_test.rb` — join-model coverage.
- `test/models/search_preference_test.rb` — zone association and validation coverage.
- `test/models/listing_test.rb` — spatial/fallback feed filtering coverage.
- `test/services/scraping/listing_geometry_builder_test.rb` — geometry normalization coverage.
- `test/services/scraping/listing_scope_validator_test.rb` — Montevideo validation coverage.
- `test/services/scraping/listing_intake_test.rb` — listing persistence with coordinates and unresolved status.
- `test/services/sources/info_casas_api_adapter_test.rb` — broadened acquisition and coordinate normalization coverage.
- `test/controllers/listings_controller_test.rb` — end-to-end feed behavior using zones.

### Task 1: Add PostGIS support and internal zone tables

**Files:**
- Modify: `Gemfile`
- Modify: `config/database.yml`
- Create: `db/migrate/20260705120000_enable_postgis_and_add_zone_tables.rb`
- Create: `app/models/zone.rb`
- Create: `app/models/search_zone.rb`
- Modify: `app/models/search_preference.rb`
- Test: `test/models/zone_test.rb`
- Test: `test/models/search_zone_test.rb`
- Test: `test/models/search_preference_test.rb`

**Interfaces:**
- Consumes: existing `SearchPreference` model and PostgreSQL database.
- Produces:
  - `class Zone < ApplicationRecord`
  - `class SearchZone < ApplicationRecord`
  - `SearchPreference has_many :search_zones` and `has_many :zones, through: :search_zones`
  - `zones.geom` multipolygon column and `zones.aliases` string-array column

- [ ] **Step 1: Write failing zone model tests**

```ruby
# test/models/zone_test.rb
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
```

```ruby
# test/models/search_zone_test.rb
require "test_helper"

class SearchZoneTest < ActiveSupport::TestCase
  test "enforces uniqueness per search and zone" do
    user = User.create!(first_name: "Search", last_name: "Owner", email: "zone-owner@example.com", password: "password123", password_confirmation: "password123")
    search = user.search_preferences.create!(name: "Coast", location_query: "legacy")
    zone = Zone.create!(name: "Pocitos", slug: "pocitos", aliases: ["pocitos"], geom: Zone.polygon_from_coordinates([[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]))
    SearchZone.create!(search_preference: search, zone: zone)

    duplicate = SearchZone.new(search_preference: search, zone: zone)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:zone_id], "has already been taken"
  end
end
```

```ruby
# test/models/search_preference_test.rb
test "requires at least one zone once zone search is enabled" do
  user = User.create!(first_name: "Search", last_name: "Owner", email: "search-owner-2@example.com", password: "password123", password_confirmation: "password123")
  search_preference = user.search_preferences.build(name: "Pocitos", location_query: "legacy")

  assert_not search_preference.valid?
  assert_includes search_preference.errors[:zones], "must include at least one zone"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/zone_test.rb test/models/search_zone_test.rb test/models/search_preference_test.rb`

Expected: FAIL with uninitialized constants, missing tables, or missing associations.

- [ ] **Step 3: Add PostGIS gems and adapter configuration**

```ruby
# Gemfile
gem "rails", "~> 8.0.2"
gem "pg", ">= 1.5"
gem "activerecord-postgis-adapter"
gem "rgeo"
gem "puma"
gem "solid_cache"
gem "solid_queue"
gem "bootsnap", require: false
gem "devise"
```

```yaml
# config/database.yml
default: &default
  adapter: postgis
  encoding: unicode
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

- [ ] **Step 4: Add migration and models**

```ruby
# db/migrate/20260705120000_enable_postgis_and_add_zone_tables.rb
class EnablePostgisAndAddZoneTables < ActiveRecord::Migration[8.0]
  def change
    enable_extension "postgis"

    create_table :zones do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :aliases, array: true, default: [], null: false
      t.multi_polygon :geom, geographic: true, srid: 4326, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :zones, :slug, unique: true
    add_index :zones, :geom, using: :gist

    create_table :search_zones do |t|
      t.references :search_preference, null: false, foreign_key: true
      t.references :zone, null: false, foreign_key: true
      t.timestamps
    end

    add_index :search_zones, [:search_preference_id, :zone_id], unique: true
  end
end
```

```ruby
# app/models/zone.rb
class Zone < ApplicationRecord
  FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

  has_many :search_zones, dependent: :destroy
  has_many :search_preferences, through: :search_zones

  validates :name, :slug, :geom, presence: true
  validates :slug, uniqueness: true

  before_validation :normalize_aliases

  def self.polygon_from_coordinates(coordinates)
    points = coordinates.map { |lng, lat| FACTORY.point(lng, lat) }
    FACTORY.multi_polygon([FACTORY.polygon(FACTORY.linear_ring(points))])
  end

  private

  def normalize_aliases
    self.aliases = aliases.map { |value| value.to_s.strip.downcase }.reject(&:blank?).uniq
  end
end
```

```ruby
# app/models/search_zone.rb
class SearchZone < ApplicationRecord
  belongs_to :search_preference
  belongs_to :zone

  validates :zone_id, uniqueness: { scope: :search_preference_id }
end
```

```ruby
# app/models/search_preference.rb
class SearchPreference < ApplicationRecord
  belongs_to :user

  has_many :notification_events, dependent: :restrict_with_exception
  has_many :search_zones, dependent: :destroy
  has_many :zones, through: :search_zones

  validates :name, :location_query, presence: true
  validate :must_have_at_least_one_zone

  scope :ordered_for_sidebar, -> { order(:created_at, :id) }

  private

  def must_have_at_least_one_zone
    errors.add(:zones, "must include at least one zone") if zones.empty?
  end
end
```

- [ ] **Step 5: Run tests and migrations**

Run: `bin/rails db:migrate test:prepare && bin/rails test test/models/zone_test.rb test/models/search_zone_test.rb test/models/search_preference_test.rb`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Gemfile config/database.yml db/migrate/20260705120000_enable_postgis_and_add_zone_tables.rb app/models/zone.rb app/models/search_zone.rb app/models/search_preference.rb test/models/zone_test.rb test/models/search_zone_test.rb test/models/search_preference_test.rb db/schema.rb
git commit -m "feat: add postgis zones"
```

### Task 2: Persist listing coordinates, geometry, and resolution state

**Files:**
- Create: `db/migrate/20260705121000_add_location_fields_to_listings.rb`
- Create: `app/services/scraping/listing_geometry_builder.rb`
- Modify: `app/services/scraping/listing_intake.rb`
- Modify: `app/models/listing.rb`
- Test: `test/services/scraping/listing_geometry_builder_test.rb`
- Test: `test/services/scraping/listing_intake_test.rb`
- Test: `test/models/listing_test.rb`

**Interfaces:**
- Consumes: normalized adapter attributes hash passed into `Scraping::ListingIntake#call`.
- Produces:
  - `Scraping::ListingGeometryBuilder#call(attributes:) -> Hash`
  - `listings.latitude`, `listings.longitude`, `listings.coordinates`, `listings.location_resolution_status`, `listings.source_neighborhood`

- [ ] **Step 1: Write failing geometry and intake tests**

```ruby
# test/services/scraping/listing_geometry_builder_test.rb
require "test_helper"

class Scraping::ListingGeometryBuilderTest < ActiveSupport::TestCase
  test "builds coordinates and marks listing spatially resolvable" do
    result = Scraping::ListingGeometryBuilder.new.call(attributes: {
      latitude: -34.9012,
      longitude: -56.1645,
      source_neighborhood: "Pocitos"
    })

    assert_equal "spatial", result[:location_resolution_status]
    assert_equal(-34.9012, result[:latitude])
    assert_equal(-56.1645, result[:longitude])
    assert result[:coordinates].present?
  end

  test "marks listing unresolved when no coordinates or fallback neighborhood exist" do
    result = Scraping::ListingGeometryBuilder.new.call(attributes: {
      location_text: "Montevideo"
    })

    assert_equal "unresolved", result[:location_resolution_status]
    assert_nil result[:coordinates]
  end
end
```

```ruby
# test/services/scraping/listing_intake_test.rb
test "persists coordinates neighborhood and resolution status from normalized attributes" do
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  intake = Scraping::ListingIntake.new

  listing = intake.call(
    listing_source: source,
    attributes: {
      title: "Apto Pocitos",
      canonical_url: "https://example.test/a",
      external_id: "1",
      latitude: -34.9012,
      longitude: -56.1645,
      source_neighborhood: "Pocitos"
    }
  )

  assert_equal "spatial", listing.location_resolution_status
  assert_equal "Pocitos", listing.source_neighborhood
  assert listing.coordinates.present?
end
```

```ruby
# test/models/listing_test.rb
test "spatially_resolvable scope returns listings with coordinates" do
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  Listing.create!(listing_source: source, title: "Spatial", canonical_url: "https://example.test/spatial", location_resolution_status: "spatial", latitude: -34.90, longitude: -56.16, coordinates: Zone::FACTORY.point(-56.16, -34.90))
  Listing.create!(listing_source: source, title: "Fallback", canonical_url: "https://example.test/fallback", location_resolution_status: "fallback", source_neighborhood: "Pocitos")

  assert_equal ["Spatial"], Listing.spatially_resolvable.pluck(:title)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/scraping/listing_geometry_builder_test.rb test/services/scraping/listing_intake_test.rb test/models/listing_test.rb`

Expected: FAIL with unknown columns, missing service, or missing scope errors.

- [ ] **Step 3: Add listing location migration and geometry builder**

```ruby
# db/migrate/20260705121000_add_location_fields_to_listings.rb
class AddLocationFieldsToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :latitude, :decimal, precision: 10, scale: 6
    add_column :listings, :longitude, :decimal, precision: 10, scale: 6
    add_column :listings, :source_neighborhood, :string
    add_column :listings, :location_resolution_status, :string, null: false, default: "unresolved"
    add_column :listings, :in_scope, :boolean, null: false, default: true
    add_column :listings, :scope_rejection_reason, :string
    add_column :listings, :coordinates, :st_point, geographic: true, srid: 4326

    add_index :listings, :coordinates, using: :gist
    add_index :listings, :location_resolution_status
    add_index :listings, :in_scope
  end
end
```

```ruby
# app/services/scraping/listing_geometry_builder.rb
module Scraping
  class ListingGeometryBuilder
    def call(attributes:)
      attrs = attributes.dup
      latitude = decimal_or_nil(attrs[:latitude])
      longitude = decimal_or_nil(attrs[:longitude])

      if latitude && longitude
        attrs[:latitude] = latitude
        attrs[:longitude] = longitude
        attrs[:coordinates] = Zone::FACTORY.point(longitude, latitude)
        attrs[:location_resolution_status] = "spatial"
      elsif attrs[:source_neighborhood].present? || attrs[:location_text].present?
        attrs[:coordinates] = nil
        attrs[:location_resolution_status] = "fallback"
      else
        attrs[:coordinates] = nil
        attrs[:location_resolution_status] = "unresolved"
      end

      attrs
    end

    private

    def decimal_or_nil(value)
      return if value.blank?

      BigDecimal(value.to_s)
    end
  end
end
```

- [ ] **Step 4: Update intake and listing scopes**

```ruby
# app/services/scraping/listing_intake.rb
def listing_attributes(attributes)
  attrs = Scraping::ListingGeometryBuilder.new.call(attributes: attributes.dup)
  attrs[:raw_payload] = attributes
  attrs
end
```

```ruby
# app/models/listing.rb
scope :recent_first, -> { order(created_at: :desc) }
scope :in_scope_inventory, -> { where(in_scope: true) }
scope :spatially_resolvable, -> { where(location_resolution_status: "spatial") }
scope :fallback_only, -> { where(location_resolution_status: "fallback") }
scope :unresolved_location, -> { where(location_resolution_status: "unresolved") }
```

- [ ] **Step 5: Run migrations and tests**

Run: `bin/rails db:migrate test:prepare && bin/rails test test/services/scraping/listing_geometry_builder_test.rb test/services/scraping/listing_intake_test.rb test/models/listing_test.rb`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add db/migrate/20260705121000_add_location_fields_to_listings.rb app/services/scraping/listing_geometry_builder.rb app/services/scraping/listing_intake.rb app/models/listing.rb test/services/scraping/listing_geometry_builder_test.rb test/services/scraping/listing_intake_test.rb test/models/listing_test.rb db/schema.rb
git commit -m "feat: persist listing geometry"
```

### Task 3: Enforce Montevideo-only inventory and broaden InfoCasas acquisition

**Files:**
- Create: `app/services/scraping/listing_scope_validator.rb`
- Modify: `app/services/scraping/listing_intake.rb`
- Modify: `app/services/sources/info_casas_api_adapter.rb`
- Test: `test/services/scraping/listing_scope_validator_test.rb`
- Test: `test/services/sources/info_casas_api_adapter_test.rb`
- Test: `test/services/scraping/listing_intake_test.rb`

**Interfaces:**
- Consumes: normalized adapter attributes before persistence.
- Produces:
  - `Scraping::ListingScopeValidator#call(attributes:) -> Hash`
  - `Sources::InfoCasasApiAdapter#fetch_listings -> Array<Hash>` using broad Montevideo source constraints

- [ ] **Step 1: Write failing validation and adapter tests**

```ruby
# test/services/scraping/listing_scope_validator_test.rb
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
```

```ruby
# test/services/sources/info_casas_api_adapter_test.rb
test "fetch_listings requests broad montevideo inventory without legacy map filters" do
  adapter = Sources::InfoCasasApiAdapter.new

  params = adapter.send(:legacy_search_params)

  assert_equal [], params[:map_polygon]
  assert_equal [], params[:map_bounds]
  assert_equal [10], params[:estate_id]
end

test "fetch_listings returns coordinates and source metadata" do
  adapter = Sources::InfoCasasApiAdapter.new

  response = stubbed_info_casas_response(
    id: 123,
    title: "Apto Malvin",
    location_name: "Malvín",
    latitude: -34.885,
    longitude: -56.082
  )

  adapter.stub(:http_response, Struct.new(:body).new(response)) do
    listing = adapter.fetch_listings.first

    assert_equal -34.885, listing[:latitude]
    assert_equal -56.082, listing[:longitude]
    assert_equal "Malvín", listing[:source_neighborhood]
    assert_equal "Montevideo", listing[:source_city]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/scraping/listing_scope_validator_test.rb test/services/sources/info_casas_api_adapter_test.rb test/services/scraping/listing_intake_test.rb`

Expected: FAIL with missing service, wrong request params, or missing normalized fields.

- [ ] **Step 3: Add scope validator and wire it into intake**

```ruby
# app/services/scraping/listing_scope_validator.rb
module Scraping
  class ListingScopeValidator
    MONTEVIDEO_NAMES = ["montevideo"].freeze
    RENTAL_NAMES = ["alquiler"].freeze

    def call(attributes:)
      attrs = attributes.dup
      city = attrs[:source_city].to_s.downcase
      operation = attrs[:operation_type].to_s.downcase

      attrs[:in_scope] = MONTEVIDEO_NAMES.include?(city) && RENTAL_NAMES.include?(operation)
      attrs[:scope_rejection_reason] = rejection_reason(city:, operation:) unless attrs[:in_scope]
      attrs
    end

    private

    def rejection_reason(city:, operation:)
      return "outside_montevideo" unless MONTEVIDEO_NAMES.include?(city)
      return "not_rental" unless RENTAL_NAMES.include?(operation)

      "unknown_scope_failure"
    end
  end
end
```

```ruby
# app/services/scraping/listing_intake.rb
def listing_attributes(attributes)
  attrs = Scraping::ListingGeometryBuilder.new.call(attributes: attributes.dup)
  attrs = Scraping::ListingScopeValidator.new.call(attributes: attrs)
  attrs[:raw_payload] = attributes
  attrs
end
```

- [ ] **Step 4: Broaden the InfoCasas adapter**

```ruby
# app/services/sources/info_casas_api_adapter.rb
def legacy_search_params
  {
    page: 1,
    order: 2,
    operation_type_id: 2,
    property_type_id: [2],
    currencyID: 2,
    m2Currency: 2,
    mapView: false,
    estate_id: [10],
    neighborhood_id: [],
    bedrooms: nil,
    publicationDate: nil,
    minPrice: nil,
    maxPrice: nil,
    m2Min: nil,
    m2Max: nil,
    map_polygon: [],
    map_bounds: []
  }
end

def fetch_listings
  payload.dig(0, :data, :searchFast, :data).map do |entry|
    {
      external_id: entry[:id].to_s,
      title: entry[:title],
      canonical_url: URI.join(FRONTEND_BASE_URL, entry[:link]).to_s,
      description: entry[:description],
      price_cents: normalize_price(entry[:price]),
      currency: "UYU",
      location_text: entry.dig(:location, :name),
      source_neighborhood: entry.dig(:location, :name),
      source_city: "Montevideo",
      operation_type: "alquiler",
      bedrooms: integer_or_nil(entry[:bedrooms]),
      square_meters: integer_or_nil(entry[:area]),
      latitude: entry[:lat] || entry.dig(:location, :lat),
      longitude: entry[:lng] || entry.dig(:location, :lng)
    }
  end
end
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/services/scraping/listing_scope_validator_test.rb test/services/sources/info_casas_api_adapter_test.rb test/services/scraping/listing_intake_test.rb`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/services/scraping/listing_scope_validator.rb app/services/scraping/listing_intake.rb app/services/sources/info_casas_api_adapter.rb test/services/scraping/listing_scope_validator_test.rb test/services/sources/info_casas_api_adapter_test.rb test/services/scraping/listing_intake_test.rb
git commit -m "feat: broaden montevideo inventory"
```

### Task 4: Replace text-only feed filtering with zone-aware matching

**Files:**
- Modify: `app/models/listing.rb`
- Modify: `app/controllers/listings_controller.rb`
- Test: `test/models/listing_test.rb`
- Test: `test/controllers/listings_controller_test.rb`

**Interfaces:**
- Consumes: `SearchPreference#zones`, listing coordinates, `zones.aliases`, and scalar search fields.
- Produces:
  - `Listing.for_search_feed(search_preference) -> ActiveRecord::Relation`
  - feed behavior that matches by zone OR semantics and scalar filters

- [ ] **Step 1: Write failing zone-aware feed tests**

```ruby
# test/models/listing_test.rb
test "for_search_feed matches any attached zone spatially" do
  user = User.create!(first_name: "Listing", last_name: "Owner", email: "listing-owner-3@example.com", password: "password123", password_confirmation: "password123")
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  pocitos = Zone.create!(name: "Pocitos", slug: "pocitos", aliases: ["pocitos"], geom: Zone.polygon_from_coordinates([[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]))
  malvin = Zone.create!(name: "Malvin", slug: "malvin", aliases: ["malvín", "malvin"], geom: Zone.polygon_from_coordinates([[-56.11, -34.91], [-56.06, -34.91], [-56.06, -34.87], [-56.11, -34.87], [-56.11, -34.91]]))
  listing = Listing.create!(listing_source: source, title: "Apto Malvin", canonical_url: "https://example.test/8", latitude: -34.885, longitude: -56.082, coordinates: Zone::FACTORY.point(-56.082, -34.885), location_resolution_status: "spatial", in_scope: true)
  search = user.search_preferences.create!(name: "Coast", location_query: "legacy", zones: [pocitos, malvin])

  assert_equal [listing], Listing.for_search_feed(search).to_a
end

test "for_search_feed falls back to aliases when coordinates are missing" do
  user = User.create!(first_name: "Listing", last_name: "Owner", email: "listing-owner-4@example.com", password: "password123", password_confirmation: "password123")
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  zone = Zone.create!(name: "Pocitos", slug: "pocitos", aliases: ["pocitos", "pocitos nuevo"], geom: Zone.polygon_from_coordinates([[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]))
  listing = Listing.create!(listing_source: source, title: "Alias Match", canonical_url: "https://example.test/9", source_neighborhood: "Pocitos Nuevo", location_resolution_status: "fallback", in_scope: true)
  search = user.search_preferences.create!(name: "Pocitos", location_query: "legacy", zones: [zone])

  assert_equal [listing], Listing.for_search_feed(search).to_a
end
```

```ruby
# test/controllers/listings_controller_test.rb
test "signed in user sees listings from any attached zone and not unresolved records" do
  user = create_user!(email: "zones@example.com")
  sign_in user
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  pocitos = Zone.create!(name: "Pocitos", slug: "pocitos", aliases: ["pocitos"], geom: Zone.polygon_from_coordinates([[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]))
  malvin = Zone.create!(name: "Malvin", slug: "malvin", aliases: ["malvín", "malvin"], geom: Zone.polygon_from_coordinates([[-56.11, -34.91], [-56.06, -34.91], [-56.06, -34.87], [-56.11, -34.87], [-56.11, -34.91]]))
  Listing.create!(listing_source: source, title: "Pocitos Match", canonical_url: "https://example.test/10", coordinates: Zone::FACTORY.point(-56.16, -34.90), latitude: -34.90, longitude: -56.16, location_resolution_status: "spatial", in_scope: true)
  Listing.create!(listing_source: source, title: "Malvin Match", canonical_url: "https://example.test/11", coordinates: Zone::FACTORY.point(-56.082, -34.885), latitude: -34.885, longitude: -56.082, location_resolution_status: "spatial", in_scope: true)
  Listing.create!(listing_source: source, title: "Unresolved", canonical_url: "https://example.test/12", location_resolution_status: "unresolved", in_scope: true)
  search = user.search_preferences.create!(name: "Coast", location_query: "legacy", zones: [pocitos, malvin])

  get listings_path(search_id: search.id)

  assert_response :success
  assert_includes response.body, "Pocitos Match"
  assert_includes response.body, "Malvin Match"
  refute_includes response.body, "Unresolved"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/listing_test.rb test/controllers/listings_controller_test.rb`

Expected: FAIL because `Listing.for_search_feed` still uses text-only `location_query` behavior.

- [ ] **Step 3: Implement zone-aware feed filtering**

```ruby
# app/models/listing.rb
class Listing < ApplicationRecord
  belongs_to :listing_source
  belongs_to :scraping_run, optional: true

  has_many :notification_events, dependent: :restrict_with_exception
  has_many :seen_listings, dependent: :nullify

  validates :title, :canonical_url, presence: true
  validates :canonical_url, uniqueness: { scope: :listing_source_id }
  validates :external_id, uniqueness: { scope: :listing_source_id }, allow_nil: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :in_scope_inventory, -> { where(in_scope: true) }
  scope :spatially_resolvable, -> { where(location_resolution_status: "spatial") }
  scope :fallback_only, -> { where(location_resolution_status: "fallback") }
  scope :unresolved_location, -> { where(location_resolution_status: "unresolved") }

  def self.for_search_feed(search_preference)
    return recent_first.none unless search_preference

    listings = in_scope_inventory.where(id: zone_matching_ids(search_preference))
    listings = listings.where("price_cents >= ?", search_preference.min_price_cents) if search_preference.min_price_cents.present?
    listings = listings.where("price_cents <= ?", search_preference.max_price_cents) if search_preference.max_price_cents.present?
    listings = listings.where("bedrooms >= ?", search_preference.min_bedrooms) if search_preference.min_bedrooms.present?
    listings.recent_first
  end

  def self.zone_matching_ids(search_preference)
    zone_ids = search_preference.zones.select(:id)

    spatial_ids = joins("INNER JOIN zones ON ST_Intersects(zones.geom, listings.coordinates)")
      .where(location_resolution_status: "spatial")
      .where("zones.id IN (?)", zone_ids)
      .select(:id)

    aliases = search_preference.zones.flat_map(&:aliases).uniq
    fallback_ids = fallback_only.where(source_neighborhood: aliases.map(&:downcase)).select(:id)

    from("((#{spatial_ids.to_sql}) UNION (#{fallback_ids.to_sql})) listings")
  end
end
```

```ruby
# app/controllers/listings_controller.rb
class ListingsController < ApplicationController
  def index
    @searches = current_user.search_preferences.includes(:zones).ordered_for_sidebar
    @active_search = @searches.find_by(id: params[:search_id]) || @searches.first
    @listings = @active_search ? Listing.includes(:listing_source).for_search_feed(@active_search) : Listing.none
  end
end
```

- [ ] **Step 4: Normalize fallback comparisons if tests expose case mismatches**

```ruby
# app/models/listing.rb
fallback_ids = fallback_only.where("LOWER(source_neighborhood) IN (?)", aliases.map(&:downcase)).select(:id)
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/models/listing_test.rb test/controllers/listings_controller_test.rb`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/models/listing.rb app/controllers/listings_controller.rb test/models/listing_test.rb test/controllers/listings_controller_test.rb
git commit -m "feat: add zone-based feed filtering"
```

### Task 5: Seed curated Montevideo zones and update demo searches

**Files:**
- Modify: `db/seeds.rb`
- Test: `test/controllers/listings_controller_test.rb`
- Test: `test/models/search_preference_test.rb`

**Interfaces:**
- Consumes: `Zone`, `SearchPreference`, and demo user seed data.
- Produces:
  - seeded Montevideo zones
  - demo saved searches attached to seeded zones

- [ ] **Step 1: Write failing seed-oriented expectations in existing tests**

```ruby
# test/models/search_preference_test.rb
test "belongs to many zones through search_zones" do
  user = User.create!(first_name: "Search", last_name: "Owner", email: "search-owner-3@example.com", password: "password123", password_confirmation: "password123")
  zone = Zone.create!(name: "Centro", slug: "centro", aliases: ["centro"], geom: Zone.polygon_from_coordinates([[-56.21, -34.92], [-56.17, -34.92], [-56.17, -34.89], [-56.21, -34.89], [-56.21, -34.92]]))
  search = user.search_preferences.create!(name: "Centro", location_query: "legacy", zones: [zone])

  assert_equal [zone], search.zones
end
```

```ruby
# test/controllers/listings_controller_test.rb
test "signed in user sidebar still renders search names when searches are zone-backed" do
  user = create_user!(email: "sidebar-zones@example.com")
  sign_in user
  zone = Zone.create!(name: "Pocitos", slug: "pocitos", aliases: ["pocitos"], geom: Zone.polygon_from_coordinates([[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]]))
  user.search_preferences.create!(name: "Pocitos", location_query: "legacy", zones: [zone])

  get listings_path

  assert_response :success
  assert_includes response.body, "Pocitos"
end
```

- [ ] **Step 2: Run tests to verify they fail if associations are not fully wired in seed assumptions**

Run: `bin/rails test test/models/search_preference_test.rb test/controllers/listings_controller_test.rb`

Expected: FAIL if any remaining fixtures or validations still assume text-only searches.

- [ ] **Step 3: Update seeds with curated Montevideo zones and demo associations**

```ruby
# db/seeds.rb
unless Rails.env.production?
  ListingSource.find_or_create_by!(adapter_key: "mock_source") { |source| source.name = "Mock Source" }
  ListingSource.find_or_create_by!(adapter_key: "info_casas_api") { |source| source.name = "InfoCasas API" }

  demo_user = User.find_or_create_by!(email: "demo@example.com") do |user|
    user.first_name = "Demo"
    user.last_name = "User"
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  zone_definitions = {
    "Pocitos" => { slug: "pocitos", aliases: ["pocitos", "pocitos nuevo"], coords: [[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]] },
    "Centro" => { slug: "centro", aliases: ["centro"], coords: [[-56.21, -34.92], [-56.17, -34.92], [-56.17, -34.89], [-56.21, -34.89], [-56.21, -34.92]] },
    "Carrasco" => { slug: "carrasco", aliases: ["carrasco", "carrasco norte"], coords: [[-56.07, -34.91], [-56.01, -34.91], [-56.01, -34.86], [-56.07, -34.86], [-56.07, -34.91]] }
  }

  zones = zone_definitions.transform_values do |attrs|
    Zone.find_or_create_by!(slug: attrs[:slug]) do |zone|
      zone.name = zone_definitions.key(attrs)
      zone.aliases = attrs[:aliases]
      zone.geom = Zone.polygon_from_coordinates(attrs[:coords])
    end
  end

  {
    "Pocitos" => [zones["Pocitos"]],
    "Centro" => [zones["Centro"]],
    "Carrasco" => [zones["Carrasco"]]
  }.each do |name, attached_zones|
    search = demo_user.search_preferences.find_or_initialize_by(name: name)
    search.location_query = name
    search.zones = attached_zones
    search.save!
  end
end
```

- [ ] **Step 4: Run seed-aware tests**

Run: `bin/rails test test/models/search_preference_test.rb test/controllers/listings_controller_test.rb`

Expected: PASS

- [ ] **Step 5: Smoke-test the seed path**

Run: `bin/rails db:seed && bin/rails runner 'puts({zones: Zone.count, searches: SearchPreference.count}.inspect)'`

Expected: output includes at least `zones: 3`

- [ ] **Step 6: Commit**

```bash
git add db/seeds.rb test/models/search_preference_test.rb test/controllers/listings_controller_test.rb
git commit -m "feat: seed montevideo zones"
```

## Self-Review

- **Spec coverage:**
  - Montevideo-only broad inventory: Task 3
  - PostGIS-backed named zones: Tasks 1 and 5
  - listing coordinates and resolution state: Task 2
  - multiple zones per saved search with OR semantics: Task 4
  - spatial-first, alias-fallback matching: Task 4
  - unresolved listings preserved: Tasks 2 and 4
  - custom polygons deferred: documented in spec, intentionally not implemented here
- **Placeholder scan:** no TBD/TODO placeholders remain in task steps.
- **Type consistency:** `Zone`, `SearchZone`, `Listing.for_search_feed`, `Scraping::ListingGeometryBuilder`, and `Scraping::ListingScopeValidator` are defined before later tasks consume them.
