# Ticket 007 Scraper Domain ADR Design

## Context
Rental Scout Lite is not an abstract new product. It is the continuation of an already validated idea.

There are two important predecessor projects:

1. **`../home_scraper`**
   - This was the original working scraper.
   - Its job was straightforward: scrape apartment listings and send notifications.
   - It is important because the scraper behavior itself proved useful in practice.
   - For scraping behavior, source handling, and the general loop of discovering listings and notifying on them, this project is the strongest practical reference.

2. **`../scraper`**
   - This was the hand-built attempt to turn the original scraper into a proper application.
   - The product intention there is the same as Rental Scout Lite: not just a scraper, but an app wrapper around the scraper behavior.
   - Its search/source/run modeling contains technical decisions that are still considered good.
   - The key difference now is not the product idea, but the delivery method: instead of building it manually, the work is being delegated to AI.

This means Rental Scout Lite should not invent a new direction unnecessarily.

**Scraper behavior should stay close to `../home_scraper`, because that worked.**

**Application/domain structure should be heavily inspired by `../scraper`, because that expresses the intended app design.**

## Purpose of Ticket 007
Ticket 007 should produce a technical ADR that defines the scraper domain clearly enough to guide the next implementation tickets without pretending that every structural decision is permanently frozen.

The ADR should record:
- what the current domain objects mean
- which architectural decisions are deliberate
- which parts are provisional and may still be reshaped later

## Goals
- Preserve the proven scraping loop from `../home_scraper`.
- Align the app wrapper and domain modeling with the intent expressed in `../scraper`.
- Clarify the meaning of current core entities in Rental Scout Lite.
- Define invariants for deduplication, “new listing” detection, and notification idempotency.
- Give Tickets 008 and 009 a stable enough domain baseline to extend.

## Non-Goals
- Rewriting all current code immediately.
- Designing provider-specific scraping logic in detail.
- Finalizing every future search or notification concept permanently.
- Defining the full frontend UX in this ADR.

## Approaches Considered

### 1. Lightweight ADR with stable core + explicit provisional areas
**Recommendation.**

Pros:
- Gives enough structure for the next tickets.
- Reflects real prior working systems instead of guessing from scratch.
- Avoids locking every detail prematurely.
- Lets the user review and later reshape the final structure consciously.

Cons:
- Some decisions remain intentionally open.
- Later refactoring is still possible if new tickets reveal better boundaries.

### 2. Strong ADR that locks the current bootstrap structure now
Pros:
- Maximum short-term clarity.
- Reduces ambiguity for implementers.

Cons:
- Risks freezing the wrong shape before enough practical iteration.
- Conflicts with the desire to review the final structure and change it if needed.

### 3. Very loose domain note with minimal commitments
Pros:
- Maximum flexibility.

Cons:
- Weak guidance for upcoming tickets.
- Higher risk of inconsistent implementation.

## Decision
Ticket 007 should produce a **technical ADR** whose job is to define a stable-enough scraper domain while explicitly marking revisitable areas.

The ADR should treat:
- `../home_scraper` as the reference for **scraper loop behavior**
- `../scraper` as the reference for **app/domain structure and product intention**

Rental Scout Lite is therefore not inventing a fresh product. It is formalizing the next implementation of the same app idea, with AI performing the development work.

## Domain Direction to Record

### 1. Listing
A `Listing` is the normalized apartment record used by the app.

It should represent the app’s stable internal shape for apartment data, independent of source-specific HTML or API payload details.

At minimum, it should hold the normalized attributes the app needs to browse and compare apartments, such as:
- title
- canonical URL
- external ID when available
- price
- location text
- bedrooms
- square meters
- source relationship
- raw payload for source traceability

### 2. ListingSource
A `ListingSource` represents a source registry entry for one provider/source feed.

It is part provider identity and part runtime configuration anchor. The current bootstrap uses one source record plus adapter resolution by key. That direction is acceptable, but the ADR should explicitly leave room for future refinement if one provider later needs multiple source instances or feed variants.

### 3. ScrapingRun
A `ScrapingRun` is one top-level scraping execution.

It should represent the overall run event, not one source-specific slice. This matches the desired orchestrated-run model and gives the app one record for the scheduler’s execution.

### 4. ScrapingSourceRun
A `ScrapingSourceRun` is the per-source outcome inside a top-level `ScrapingRun`.

This distinction is important and should be explicit in the ADR:
- one `ScrapingRun` = one scheduler-triggered scraping pass
- many `ScrapingSourceRun`s = the result of running that pass against individual sources

This structure is the clearest way to preserve source isolation while still keeping one overall run concept.

### 5. SeenListing
A `SeenListing` is the deduplication memory of a listing seen from a source.

Its role is not just historical bookkeeping. It is part of the app’s idempotency and repeated-run safety.

The ADR should state that deduplication memory is first-class, not incidental.

### 6. NotificationEvent
A `NotificationEvent` records that a listing matched the relevant criteria strongly enough to create a notification-worthy event.

The ADR should separate:
- match/detection
- event creation
- eventual delivery

This keeps notification logic explicit and auditable.

## Deduplication Rules
The ADR should define deduplication in this order of trust:

1. **source + external ID**, when external ID exists
2. **source + canonical URL**, when external ID is absent or unstable

The app should treat these as the main identity anchors for deciding whether a source record refers to an already-known listing.

The ADR should also acknowledge that source data is imperfect and that URL or external ID drift may still require later refinement.

## Definition of “New Listing”
A listing counts as **new** when it is newly discovered relative to the app’s existing deduplication state, not merely because it appears in the latest scrape result.

That means:
- re-seeing a known listing is not “new”
- a newly inserted normalized listing or newly recognized dedup identity is “new”

This distinction matters for notifications and feed freshness.

## Notification Idempotency
The ADR should explicitly state:

The same listing should not produce duplicate notification events for the same logical notification context once it has already been recognized and recorded.

Exact future scoping may later include user, search, and channel dimensions more explicitly, but the principle should already be recorded now.

## Relationship to `../home_scraper`
The ADR should state that the scraper loop remains behaviorally inspired by `../home_scraper`:
- source fetch
- normalize
- dedupe
- detect new listings
- notify

Rental Scout Lite should preserve that behavioral backbone because it was already useful and proven.

## Relationship to `../scraper`
The ADR should state that app structure is intentionally inspired by `../scraper`:
- explicit source modeling
- explicit run modeling
- explicit search/domain structure
- app wrapper around scraper behavior, not scraper-only tooling

However, the ADR should also record that Rental Scout Lite is allowed to diverge where:
- the apartment domain needs different concepts
- the bootstrap already contains a simpler but valid shape
- later tickets reveal better boundaries

## Provisional Areas
The ADR should explicitly mark these as provisional:

1. **How closely saved-search/domain modeling should converge with `../scraper`**
   - The current frontend already uses `SearchPreference` as a saved-search object.
   - That may later need reshaping toward a more `Search`-centric structure if the app is brought closer to `../scraper`.

2. **Whether `Match` should become a persisted model**
   - For now it can remain domain logic or an application-level concept.
   - Persisting it is not required yet.

3. **How much source registry and adapter identity should separate**
   - The bootstrap’s `adapter_key`-driven source resolution is acceptable now.
   - It may later need refinement if a provider has multiple search/feed variants.

## Recommended ADR Shape
The produced artifact should likely live at:

`/.ai/decisions/adr-scraper-domain.md`

It should use a standard ADR structure:
- Context
- Decision
- Alternatives considered
- Consequences
- Related tickets

## Summary
Ticket 007 should create a technical ADR that records the scraper domain as the deliberate combination of two earlier truths:

- `../home_scraper` proved the scraper-and-notification loop
- `../scraper` expressed the intended application wrapper and domain structure

Rental Scout Lite should therefore keep scraper behavior close to the original working scraper, while shaping the broader application domain in a way heavily inspired by the hand-built app attempt. The ADR should stabilize the core concepts now, while clearly marking the parts that may still be reshaped later.
