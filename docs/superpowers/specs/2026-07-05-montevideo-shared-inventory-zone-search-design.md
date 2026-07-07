# Montevideo shared inventory and zone search design

## Summary

Rental Scout Lite should stop delegating user search semantics to third-party rental portals and instead treat those portals as broad inventory providers. The app will ingest a shared Montevideo-only rental inventory, persist listing coordinates and fallback location metadata, define its own internal named zones, and evaluate saved searches on our side using spatial matching first and metadata fallback second.

This first version intentionally limits the inventory universe to Montevideo rentals, supports saved searches linked to multiple named zones with OR semantics, and defers custom user-drawn polygons to a follow-up iteration.

## Goals

- Ingest broad rental inventory for Montevideo instead of user-shaped source queries
- Move saved-search filtering and zone semantics fully into Rental Scout Lite
- Support internal named zones backed by PostGIS geometry
- Allow each saved search to target multiple zones with OR matching
- Match listings spatially when coordinates exist, and by fallback aliases when they do not
- Preserve unresolved listings in inventory for later repair instead of dropping them

## Non-goals

- Expanding beyond Montevideo in this ticket
- Supporting custom user-drawn polygons in this first release
- Precomputing listing-to-search matches at ingestion time
- Building automated geodata import tooling beyond a small curated seed set
- Perfectly repairing all listings with missing or unreliable location data

## Product behavior

The app becomes the search engine. External sources only provide broad inventory within a constrained acquisition boundary.

For the first version:

- Inventory scope is Montevideo rentals only
- Source queries should be broad enough to capture relevant Montevideo rental inventory
- The Montevideo boundary should be enforced twice:
  - at source-query time where possible
  - by our own post-ingest validation before listings are accepted as in-scope inventory

Each saved search will continue to own scalar filters such as price and bedrooms, but location membership will no longer rely on source-side query shapes. Instead, a saved search will be linked to one or more internal named zones.

Matching behavior:

- A listing matches a saved search if it matches at least one of the search's zones
- Zone logic is OR across all attached zones
- A listing can match multiple saved searches
- If a listing has coordinates, spatial matching is authoritative
- If a listing lacks coordinates, fallback matching uses source neighborhood or location metadata against zone aliases
- If neither method can resolve the location, the listing stays stored but does not match zone-based searches

## Architecture

The new conceptual split is:

1. **Acquisition**: adapters fetch broad Montevideo rental inventory from each source
2. **Inventory**: normalized listings are stored in a shared internal inventory
3. **Geography**: internal named zones define the product's location model
4. **Search evaluation**: saved searches are resolved against inventory using our geography and scalar filters

The orchestration pipeline remains fundamentally the same:

`RunScrapersJob` -> `Scraping::RunOrchestrator` -> source adapter -> `Scraping::ListingIntake`

What changes is the adapter intent and the downstream query model:

- adapters no longer try to mirror the user's precise spatial search
- listings become broadly ingestible inventory records
- feed/search logic becomes a domain concern of our application, not an external API concern

## Data model direction

### Listings

`listings` should remain the shared inventory table and gain explicit location support.

Recommended additions:

- `latitude`
- `longitude`
- canonical PostGIS point column for spatial querying
- source neighborhood or locality metadata for fallback matching
- `location_resolution_status` indicating whether a listing is:
  - spatially resolvable
  - fallback-only
  - unresolved
- optional in-scope validation metadata if useful for debugging Montevideo boundary enforcement

The existing `location_text` and raw payload retention should remain useful as provenance and debugging data.

### Zones

Add an internal `zones` table representing named Montevideo areas.

Each zone should include:

- display name
- slug
- polygon or multipolygon geometry
- alias list for fallback text matching against source metadata
- active flag if useful for future operational control

The geometry is our product truth. Source-provided neighborhood names are not the primary filter mechanism.

### Search-to-zone relationship

Saved searches should have a many-to-many relation with zones.

This supports:

- multiple named zones on one saved search
- OR semantics across zones
- the same zone being reused across many saved searches

### Future match materialization

Do not require a persistent listing-to-search match table in v1, but design so it can be added later.

That future table could record:

- listing
- search preference
- matched zone(s)
- matched_at timestamp
- match strategy used (spatial vs fallback)

This is especially useful for later notifications and auditability, but it should not be required to ship the first version.

## Zone source strategy

The first version should use a small curated internal zone seed set for Montevideo.

Why this is preferred:

- fast to ship
- controllable quality
- avoids premature geo-import tooling
- aligns with the limited first-release geography

Each seeded zone should include aliases for common source neighborhood naming variants where known.

Import tooling and larger public geo-dataset ingestion are follow-up work.

## Ingestion behavior

Source adapters should fetch broad Montevideo rental inventory subject to per-source configuration. This broadness should be configurable per source, but the first seeded production behavior should target Montevideo rentals only.

Post-ingest validation should reject or flag out-of-scope listings so the shared inventory remains aligned with the product boundary.

Listings with poor location data should not be discarded purely because they are unresolved. The app should preserve them in inventory with an unresolved status so later enrichment or repair is possible.

## Search and feed evaluation

For the first implementation, zone matching should happen at read time.

Recommended evaluation order for a saved search:

1. Determine whether the listing is in at least one attached zone
   - use spatial point-in-zone when coordinates exist
   - otherwise use alias-based fallback matching
2. Apply scalar filters such as price and bedrooms
3. Return results ordered by the feed's chosen ordering logic

This preserves a simple ingestion path while leaving room for later precomputed matching if performance or notification workflows demand it.

## Matching semantics

### Spatial match

When a listing has coordinates and a valid point geometry:

- treat zone geometry as authoritative
- a point inside any attached zone is a match

### Fallback match

When a listing lacks coordinates but has source neighborhood or location metadata:

- compare normalized location metadata against zone aliases
- this is a fallback strategy, not a co-equal primary strategy

### Unresolved listings

When a listing lacks both coordinates and reliable fallback metadata:

- keep it stored in inventory
- mark it unresolved
- do not let it falsely match a zone-based saved search

### Multi-search behavior

The system should allow one listing to appear in multiple saved searches when it satisfies each saved search independently. This is expected and desired behavior.

## PostGIS role

PostGIS should be the foundation for internal zone filtering.

Use it for:

- storing named-zone geometry
- storing listing point geometry
- executing point-in-polygon matching efficiently and correctly

The design should prefer a canonical geometry/geography representation in the database over ad hoc Ruby-side polygon math.

## Migration strategy

This work can be introduced incrementally:

1. Add listing location fields and zone-related tables
2. Seed a small Montevideo zone set
3. Update source adapters to ingest broad Montevideo inventory
4. Update feed query logic to resolve saved searches through zones instead of text-only `location_query`
5. Retain fallback metadata logic for listings without coordinates

The current text-based `location_query` behavior should be migrated toward internal zone-backed search semantics rather than remain the primary long-term location filter.

## Testing strategy

Required automated coverage should include:

1. **Inventory persistence**
   - listings persist coordinates, fallback location metadata, and resolution status

2. **Zone membership**
   - listings with coordinates match the correct named zones spatially
   - listings outside a zone do not match it

3. **Fallback matching**
   - listings without coordinates can still match via zone aliases when appropriate
   - fallback does not create false positives for unrelated aliases

4. **Multiple-zone saved searches**
   - one saved search with multiple zones matches listings in any of those zones

5. **Multiple-search listing visibility**
   - one listing can appear in multiple saved searches when it independently qualifies

6. **Unresolved location handling**
   - unresolved listings are stored
   - unresolved listings do not falsely match zone-based searches

7. **Montevideo boundary enforcement**
   - source-level broad queries remain Montevideo-focused
   - post-ingest validation prevents out-of-scope inventory from being treated as valid Montevideo stock

## Risks and trade-offs

### Read-time matching cost

Read-time spatial filtering is simpler to ship but can become heavier as inventory grows. This is acceptable in v1 because it keeps ingestion decoupled from user search state.

### Incomplete source coordinates

Some source listings may have missing or low-quality coordinates. The fallback alias strategy reduces data loss, but coverage may still be imperfect until enrichment tooling exists.

### Curated zone maintenance

A manual seed set is practical early on, but it creates an ongoing maintenance burden until import tooling or a trusted external geometry source is introduced.

## Follow-up work

Explicit follow-ups after this ticket:

- support user-drawn polygons as additional zone types
- add precomputed listing-to-search matches for notifications and scale
- build enrichment and repair workflows for unresolved listings
- expand inventory beyond Montevideo when product scope justifies it
- introduce broader zone import tooling or external geometry sync if needed

## Success criteria

This design is successful when:

- third-party sources are treated as broad Montevideo inventory providers
- listings are stored with enough location data to support internal search evaluation
- named Montevideo zones exist in our system with PostGIS-backed geometry
- saved searches can target multiple zones with OR semantics
- feed/search filtering is performed primarily in our app rather than delegated to third-party query APIs
- unresolved listings are preserved without contaminating search results
