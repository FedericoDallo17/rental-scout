# Home Scraper Source Expansion Implementation Plan

**For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Remax, Housi, and Imperium Inmobiliaria adapters from the old scraper project as bounded, test-covered real sources.

**Architecture:** Create one source adapter per provider using the existing `Sources::AdapterRegistry` naming convention. Each adapter performs a single list/index HTTP request, parses provider-specific JSON or HTML, and emits the current `ListingIntake` normalized attributes.

**Tech Stack:** Rails 8, Minitest, Net::HTTP, JSON, Nokogiri.

---

### Task 1: Remax API Adapter

**Files:**
- Create: `app/services/sources/remax_adapter.rb`
- Create: `test/services/sources/remax_adapter_test.rb`

- [ ] Write failing tests for RedREMAX JSON normalization and explicit HTTP timeouts.
- [ ] Run `rtk rbenv exec ruby bin/rails test test/services/sources/remax_adapter_test.rb` and verify the missing adapter failure.
- [ ] Implement `Sources::RemaxAdapter#fetch_listings` using the direct `api-ar.redremax.com` list endpoint.
- [ ] Run the focused test and verify it passes.

### Task 2: Housi HTML Adapter

**Files:**
- Create: `app/services/sources/housi_adapter.rb`
- Create: `test/services/sources/housi_adapter_test.rb`

- [ ] Write failing tests for server-rendered card parsing from `#propiedades [prop-id]`.
- [ ] Run `rtk rbenv exec ruby bin/rails test test/services/sources/housi_adapter_test.rb` and verify the missing adapter failure.
- [ ] Implement `Sources::HousiAdapter#fetch_listings` against the bounded search URL.
- [ ] Run the focused test and verify it passes.

### Task 3: Imperium API Adapter

**Files:**
- Create: `app/services/sources/imperium_inmobiliaria_adapter.rb`
- Create: `test/services/sources/imperium_inmobiliaria_adapter_test.rb`

- [ ] Write failing tests for API normalization and filtering non-apartment/bedroomless rows.
- [ ] Run `rtk rbenv exec ruby bin/rails test test/services/sources/imperium_inmobiliaria_adapter_test.rb` and verify the missing adapter failure.
- [ ] Implement `Sources::ImperiumInmobiliariaAdapter#fetch_listings` against the list API only.
- [ ] Run the focused test and verify it passes.

### Task 4: Seeds and Documentation

**Files:**
- Modify: `db/seeds.rb`
- Modify: `.ai/STATUS.md`
- Modify: `.ai/product/roadmap.md`

- [ ] Add inactive `ListingSource` seed records for `remax`, `housi`, and `imperium_inmobiliaria`.
- [ ] Update status and roadmap to show source expansion in progress/completed and MercadoLibre still paused.
- [ ] Run seed smoke in test or development as appropriate without triggering scrape jobs.

### Task 5: Verification

- [ ] Run focused adapter tests.
- [ ] Run `rtk rbenv exec ruby bin/rails test`.
- [ ] Review `rtk git diff`.
- [ ] Commit the ticket with a conventional commit message.
