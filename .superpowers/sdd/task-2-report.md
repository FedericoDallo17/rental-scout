Status: DONE_WITH_CONCERNS

Files changed:
- db/migrate/20260705121000_add_location_fields_to_listings.rb
- app/services/scraping/listing_geometry_builder.rb
- app/services/scraping/listing_intake.rb
- app/models/listing.rb
- test/services/scraping/listing_geometry_builder_test.rb
- test/services/scraping/listing_intake_test.rb
- test/models/listing_test.rb
- db/schema.rb
- .superpowers/sdd/task-2-report.md

TDD evidence:

1. Added failing tests for listing geometry building, intake persistence, and the `Listing.spatially_resolvable` scope.

2. Ran `bin/rails test test/services/scraping/listing_geometry_builder_test.rb test/services/scraping/listing_intake_test.rb test/models/listing_test.rb`

```text
Running 17 tests in a single process (parallelization threshold is 50)
Run options: --seed 39492

# Running:

E

Error:
Scraping::ListingIntakeTest#test_persists_coordinates_neighborhood_and_resolution_status_from_normalized_attributes:
ActiveModel::UnknownAttributeError: unknown attribute 'latitude' for Listing.
    app/services/scraping/listing_intake.rb:30:in `persist_listing'
    app/services/scraping/listing_intake.rb:4:in `call'
    test/services/scraping/listing_intake_test.rb:8:in `block in <class:ListingIntakeTest>'

bin/rails test test/services/scraping/listing_intake_test.rb:4

.......E

Error:
Scraping::ListingGeometryBuilderTest#test_marks_listing_unresolved_when_no_coordinates_or_fallback_neighborhood_exist:
NameError: uninitialized constant Scraping::ListingGeometryBuilder
    test/services/scraping/listing_geometry_builder_test.rb:18:in `block in <class:ListingGeometryBuilderTest>'

bin/rails test test/services/scraping/listing_geometry_builder_test.rb:17

E

Error:
Scraping::ListingGeometryBuilderTest#test_builds_coordinates_and_marks_listing_spatially_resolvable:
NameError: uninitialized constant Scraping::ListingGeometryBuilder
    test/services/scraping/listing_geometry_builder_test.rb:5:in `block in <class:ListingGeometryBuilderTest>'

bin/rails test test/services/scraping/listing_geometry_builder_test.rb:4

.....E

Error:
ListingTest#test_spatially_resolvable_scope_returns_listings_with_coordinates:
ActiveModel::UnknownAttributeError: unknown attribute 'location_resolution_status' for Listing.
    test/models/listing_test.rb:6:in `block in <class:ListingTest>'

bin/rails test test/models/listing_test.rb:4

.

Finished in 0.189987s, 89.4798 runs/s, 184.2231 assertions/s.
17 runs, 35 assertions, 0 failures, 4 errors, 0 skips
```

3. Implemented the listing location migration, `Scraping::ListingGeometryBuilder`, intake integration, and listing scopes.

4. Ran `bin/rails db:migrate test:prepare && bin/rails test test/services/scraping/listing_geometry_builder_test.rb test/services/scraping/listing_intake_test.rb test/models/listing_test.rb`

```text
== 20260705121000 AddLocationFieldsToListings: migrating ======================
-- add_column(:listings, :latitude, :decimal, {:precision=>10, :scale=>6})
   -> 0.0011s
-- add_column(:listings, :longitude, :decimal, {:precision=>10, :scale=>6})
   -> 0.0003s
-- add_column(:listings, :source_neighborhood, :string)
   -> 0.0003s
-- add_column(:listings, :location_resolution_status, :string, {:null=>false, :default=>"unresolved"})
   -> 0.0013s
-- add_column(:listings, :in_scope, :boolean, {:null=>false, :default=>true})
   -> 0.0006s
-- add_column(:listings, :scope_rejection_reason, :string)
   -> 0.0003s
-- add_column(:listings, :coordinates, :st_point, {:geographic=>true, :srid=>4326})
   -> 0.0458s
-- add_index(:listings, :coordinates, {:using=>:gist})
   -> 0.0029s
-- add_index(:listings, :location_resolution_status)
   -> 0.0011s
-- add_index(:listings, :in_scope)
   -> 0.0011s
== 20260705121000 AddLocationFieldsToListings: migrated (0.0549s) =============

Running 17 tests in a single process (parallelization threshold is 50)
Run options: --seed 34268

# Running:

.................

Finished in 0.156246s, 108.8028 runs/s, 288.0074 assertions/s.
17 runs, 45 assertions, 0 failures, 0 errors, 0 skips
```

Verification notes:
- Listing intake still persists the normalized adapter hash in `raw_payload` and only adds location enrichment before assignment.
- No zone-matching query logic was added.
- Existing `Listing.for_search_feed` behavior was left unchanged.

Concerns:
- The brief is internally inconsistent on fallback resolution: the prose test says `location_text: "Montevideo"` should remain `unresolved`, while the sample implementation would mark any present `location_text` as `fallback`. I implemented the tested behavior, so `source_neighborhood` is the fallback trigger and `location_text` alone remains `unresolved`.

Git commit(s) created:
- 7c4dc04589f01c14e30e4f4a027cecd4e9f8fc6f `feat: persist listing geometry`
