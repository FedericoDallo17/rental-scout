# State of the Project — 2026-07-06

Synthesis of a four-stream audit (architecture, runtime health, in-flight work review,
workflow retrospective) run on 2026-07-06. This is the truthful "where we are now"
document; `.ai/STATUS.md` summarizes it, and the ADRs in `.ai/decisions/` record the
decisions it produced.

## TL;DR

The ingest half of the product is real and solid; the notify/rank half is scaffolding.
Runtime health is excellent (Ruby 3.3.4 / Rails 8.0.5, PostGIS multi-DB, zero schema
drift, 104 tests green in ~2s). The working tree holds three mingled uncommitted change
sets, one of which (the coordinate backfill) is functionally broken despite green tests.
The AI dev loop's spec→plan discipline is near-perfect, but its knowledge-curation tail
(STATUS, roadmap, ADRs, feature summaries) atrophied and must be rebuilt — which this
document set does.

## What actually exists vs the README's promises

| Promise | Reality |
|---|---|
| Portal / saved-search feed | Delivered and polished (Devise auth, user-owned searches, PostGIS zone filtering) |
| Normalization + dedup | Delivered — `Scraping::ListingIntake` pipeline is source-agnostic and well-tested |
| Hourly scraping | Configured (`config/recurring.yml`, Solid Queue) but never validated end-to-end; requires the job supervisor running |
| Multi-source ingestion | Partial — one real adapter (InfoCasas) + one mock; adapter contract is implicit and unenforced |
| Ranking / match scoring | Never built — feed orders by `created_at DESC` only |
| Notification events | Never built — table, model, and `users.pushover_user_key` exist; no code creates or delivers an event |

## Solid vs scaffolding

**Solid:** intake pipeline (dedup by `external_id`/`canonical_url` with `RecordNotUnique`
recovery, PostGIS geometry building, seen-listing tracking, scope validation, raw-payload
capture); per-source failure isolation in `Scraping::RunOrchestrator`; auth and data
scoping (no IDOR); test coverage on the ingest core (~1.9x test-to-app LOC).

**Scaffolding / missing:** notifications, ranking, adapter contract enforcement,
cross-source dedup, currency handling (hardcoded UYU; price filters are currency-blind).

**Broken by construction:** the seeded demo. `MockSourceAdapter` omits `source_city` and
`operation_type`, so `ListingScopeValidator` marks every mock listing `in_scope: false`
and the out-of-the-box feed is empty. This is also the proof that the implicit adapter
contract fails silently.

**Dead code:** `app/services/sources/info_casas_legacy_map.rb` (131 LOC, mostly a
base64 polygon blob) — defined but never referenced; the adapter sends empty
`map_polygon`/`map_bounds`.

## The uncommitted working tree (three mingled change sets)

1. **InfoCasas adapter enrichment** — pagination to exhaustion, last-hour publication
   filter, broadened property types, richer normalization, JSON-LD detail-page
   coordinate scraping. Real risks: no rate limiting, no max-page guard, per-listing
   serial HTTP with 15s timeouts inside the scrape loop, silent `rescue StandardError`.
2. **Coordinate backfill job/service** — functionally dead as written: it re-fetches the
   *last-hour* feed to find *stale* coordless listings, which will almost never appear
   there. Tests pass only because they stub `fetch_listings` wholesale. Correct approach:
   fetch each listing's detail page directly via its `canonical_url`. Also: full feed
   re-crawl per 20-listing batch, and `external_ids:` mode re-processes the same IDs
   every batch.
3. **App header/nav restyle** — coherent, tested, unrelated to the geo work. Note:
   `public/stylesheets/application.css` is a hand-maintained mirror of
   `app/assets/stylesheets/application.css` (no Propshaft in the Gemfile); the diff
   replaced the honest "keep in sync" comment with false Propshaft boilerplate.

Decision: do not commit the backfill as-is; split and fix per Ticket 014.

## Architecture risks (ranked)

1. Notification pipeline absent (the core product promise — "tell me about new matches").
2. Demo feed empty by construction (mock adapter vs scope validator).
3. Scraper network N+1: serial detail-page fetches inside the paginated loop, no
   throttling — operational and ToS risk against InfoCasas.
4. Scraper fragility: `nil`-dig crash on error-shaped API responses; unbounded pagination.
5. Scrape parameters hardcoded (Montevideo/rental/last-hour) — user search preferences
   never reach the scraper, so anything outside that window is never ingested.
6. For source #2: no enforced adapter schema, Spanish-token scope validator, currency
   blindness, no cross-source dedup.
7. Minor: empty-alias zones yield invalid `IN ()` SQL; created-count passed via
   `instance_variable_get`; unindexed `price_cents`/`bedrooms` (fine at pilot scale).

## Workflow retrospective (the loop is the real product)

**Works:** spec→plan pairing was 9/9; plans are TDD-structured with verbatim red→green
evidence; specs practice strong Non-Goals discipline.

**Broke:** everything downstream of code. `.ai/STATUS.md` froze at the Ticket-007 era.
The roadmap never learned about auth or PostGIS. Only 1 ADR was ever written; Devise,
PostGIS, the "app-as-search-engine" pivot, and the silent descoping of ranking and
notifications have no decision records. `.ai/reviews/`, `.ai/feature_summaries/`,
`.ai/context_packs/`, `.ai/metrics/` are empty. 2 of 9 specs and 5 of 9 plans were never
committed. The backfill feature bypassed the loop entirely (code, no spec/plan/commit).
The real-scraper work bypassed Ticket 013's approval gate. `.ai/product/` discovery docs
are 2–4-line stubs — the loop's first three phases produced no durable content.

**Fix ratio:** ~23% `fix:` commits, all clustered on the two externally-risky areas
(live API, PostGIS) — exactly where the ADR predicted risk. The loop is smooth on
self-contained work and churny at integration boundaries.

**Root cause:** the loop has strong *forward* pressure (spec→plan→code) and no *backward*
pressure (code→docs→state). Remedy adopted: CLAUDE.md now instructs every session to
update `.ai/STATUS.md` and write ADRs for architectural decisions; superseded docs get
marked, not silently abandoned.

## Decisions made this session (details in `.ai/decisions/`)

- **adr-notifications-over-ranking** — notifications are the next headline feature;
  ranking stays descoped until a second source exists.
- **adr-adapter-contract** — an enforced normalized-attribute contract is a prerequisite
  for source #2; fix the mock adapter to satisfy it (also fixes the empty demo).
- **adr-postgis-app-as-search-engine** — retroactive record of the 07-05 pivot.
- **adr-devise-auth-shared-inventory** — retroactive record of the auth/ownership model.

## Next tickets (priority order)

1. **014 — Land the in-flight InfoCasas work** (fix backfill to use `canonical_url`
   detail fetches; add rate limiting + max-page guard; split into 3 commits).
2. **015 — Notification pipeline MVP** (producer after each scrape run + one delivery
   channel, honoring `notification_events` idempotency).
3. **016 — Adapter contract + mock adapter fix** (validate required keys at intake;
   make the seeded demo show listings again).

Deferred/killed for now: ranking (006), MercadoLibre adapter (until 016), map UI.
