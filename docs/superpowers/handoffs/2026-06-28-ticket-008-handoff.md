> **SUPERSEDED (2026-07-06):** point-in-time handoff; the work described here has since shipped. Current state: `.ai/STATUS.md`.

# Ticket 008 Handoff

## Status
Do **not** start implementation in this session. User explicitly requested a handoff for a fresh agent because current session context is too full.

## Ticket
`.ai/tickets/008-mock-source-adapter.md`

## User-approved direction
Implement Ticket 008 as a **curated realistic mock feed**.

Chosen direction:
- not a tiny stub
- not a dynamic lifecycle simulator yet
- a **static mock source** with **realistic listing shape**
- around **8–12 listings** by default
- listings should be **Montevideo-specific and curated**

## What realism matters most
The user chose:
1. **Listing shape realism** over source-behavior realism
2. **8–12 listings** as the default volume
3. **Curated Montevideo-specific listings** rather than generic ones

## Recommended implementation shape
The mock source adapter should return a meaningful fake feed, not just one demo record.

It should stay:
- static
- deterministic
- easy to test

It should help with:
- frontend card design
- saved-search feed browsing
- location / price / bedroom filtering
- future scoring work

## Fields the mock adapter should include consistently
At minimum, each listing should include:
- `external_id`
- `title`
- `canonical_url`
- `location_text`
- `price_cents`
- `bedrooms`
- `square_meters`

If already easy and aligned with current schema, consider also:
- short description/summary
- placeholder image URL later (only if the current UI is ready for it)

## Scope boundary for Ticket 008
Do **not** turn this into a behavior simulator yet.

Out of scope for this ticket:
- listings appearing/disappearing across runs
- source failure simulation
- pagination
- fake retry/error behavior
- real scraping

Those can be handled later, especially around Ticket 009 or later observability/idempotency work.

## Existing code to inspect first
Fresh agent should read these first:
- `docs/superpowers/specs/2026-06-28-ticket-007-scraper-domain-adr-design.md`
- `.ai/decisions/adr-scraper-domain.md`
- `.ai/tickets/008-mock-source-adapter.md`
- `app/services/sources/mock_source_adapter.rb`
- `app/services/sources/adapter_registry.rb`
- `app/services/scraping/run_orchestrator.rb`
- `app/services/scraping/listing_intake.rb`
- `app/models/listing.rb`
- `test/services/sources/mock_source_adapter_test.rb`
- `test/jobs/run_scrapers_job_test.rb`

## Current repo context
Recent relevant commits:
- `d4d08aa` docs: define scraper domain ADR
- `e94f119` docs: add scraper domain ADR design
- `884763b` feat: add saved-search listings feed

The frontend now has visible styling and a saved-search marketplace layout.

## Suggested next process for fresh agent
1. Use **brainstorming** first for Ticket 008
2. Write a spec/design for Ticket 008
3. Then write an implementation plan
4. Then execute with TDD

## One-sentence summary
Ticket 008 should upgrade the current mock adapter from a single demo record into a deterministic, curated Montevideo rental feed of roughly 8–12 realistic normalized listings, without yet simulating changing source behavior.