# Status

Last updated: 2026-10-23. New here? Read `.ai/WORKFLOW.md` first - it's the dev loop.
Full audit context: docs/superpowers/reports/2026-07-06-state-of-the-project.md

## Current Phase
Freshness-first MVP lifecycle and inventory-health observability complete

## Current Task
Timbre experience and rental/sale regressions verified; production deployment pending

## Status
Hourly acquisition is freshness-first: InfoCasas uses its publication window, Remax and Imperium stop bounded recent pagination at known source-local IDs, and Housi remains one page. A bounded Sunday reconciliation refreshes older inventory without notifying users. MercadoLibre remains paused until API keys or an allowed index payload sample are available.

## Done
- Click-triggered Timbre ding-dong added locally to tour activation and explicit brand replay; automatic intros remain silent. Lazy Web Audio synthesis, finish/navigation cleanup and blocked-audio fallback verified; full suite passes (327 tests, 2074 assertions). See `docs/superpowers/handoffs/2026-10-23-timbre-sound.md` (10-23).
- Rental/sale regressions fixed: Remax preserves explicit provider operation metadata, normalizes rent/sale, falls back only when metadata is absent and keeps unknown operations out of scope. The queued delivery/idempotency lifecycle and sidebar operation label now pass. Final suite: 327 tests, 2074 assertions, zero failures (10-23).
- Public tour entrance implemented locally: centered growing symbol, ringing circles, click-triggered approved D2 door/wordmark animation, then a responsive five-chapter journey. Includes skip, keyboard, reduced-motion fallback and Turbo restoration. Focused tests pass (6 tests / 72 assertions); full-suite run has two failures in listing/sidebar and queued scraper delivery tests. See `docs/superpowers/handoffs/2026-10-23-tour-entrance.md` (10-23).
- Navigation/content review implemented locally: Results is a direct first tab on desktop/mobile; authenticated navigation omits the public tour; Chimes starts with personal matches; inventory diagnostics remain in Administration; Alerts prioritizes activation with secondary help folded. Browser QA passed at desktop/tablet/320px/390px (10-23). See `docs/superpowers/handoffs/2026-10-23-timbre-navigation.md`.
- Timbre identity integrated locally: approved D2 round/no-frame/outward logo motion, Patio palette, green/ivory PWA icons and favicon, licensed local Manrope, bilingual name and es-UY brand voice. Personal history is Timbres; delivery settings are Avisos. Desktop/mobile browser QA passed, including replay, final geometry, Turbo and reduced motion. No production deployment (10-22).
- Public recruiter tour at `/tour`: bilingual five-step walkthrough with fictional rentals, budget filtering, ephemeral favorites/progress, notification preview, and technical notes; sign-in and account navigation entry points (10-10).
- User-approved apartment tracking: private favorites, editable contact/visit/rejection dates, quick today actions, paginated status filters, purge-safe snapshots and stable reingestion identity. Saved searches now persist validated min/max m², used by feed matching and notification fan-out (10-09).
- Docs, tickets, governance, mock scraper pipeline, initial portal (06-27..06-29)
- Scraper domain ADR (007)
- Devise auth + user-owned saved searches, shared listing inventory (07-03..07-04)
- Real InfoCasas API adapter timeouts error handling (07-04)
- PostGIS zones: listing geometry at intake, zone-based feed filtering (07-05)
- Hourly RunScrapersJob configured via Solid Queue recurring tasks (unvalidated end-to-end)
- Full audit + decision records + roadmap refresh (07-06)
- Workflow guardrails: CSS-mirror test, STATUS structure test (replaced frozen bootstrap snapshot), ticket Definition-of-Done, shared `.claude/settings.json`, live-scrape HTTP-layer-stubbing policy lines; `.ai/WORKFLOW.md` runbook (07-11)
- Ticket 014 landed: branded header/flash styling, InfoCasas pagination max-page guard throttles, coordinate backfill repaired fetch listing detail pages directly (07-11; concurrent session stamped 07-12 in error)
- Follow-up 014: removed inline per-listing detail from `fetch_listings`; live probe showed index returns 0/50 coordinates, so fallback would guarantee 1+N detail requests during list scrape. Coordinates now come from backfill only.
- Ticket 018 planned: MercadoLibre source ticket, design spec, implementation plan written. Read-only probes to `api.mercadolibre.com/sites/MLU/search` returned `403`, so adapter normalization must not be written against guessed provider fields.
- Ticket 011 landed: signed-in scraping run observability page shows recent run status, counts, per-source rows, error messages (07-12)
- Ticket 019 landed: signed-in users can create, edit, delete own saved searches zones filters (07-12)
- Hybrid Workbench polish landed: saved-search sidebar cards show match counts, search forms include feed context, scraping runs include feed navigation plus source timelines (07-12)
- Ticket 020 landed: Remax direct RedREMAX API adapter, Housi server-rendered HTML adapter, Imperium API adapter, raw provider samples, scrape-driven parser hardening, clickable listing cards, source activation controls, studio bedroom normalization, UYU-only price filtering, and currency labels on cards (07-12)
- Provider-sample data model follow-up landed: `expenses_cents`, `expenses_currency`, `parking_spaces`, and `property_type` columns; adapters populate available fields; cards render provider detail rows (07-12)
- Ticket 006 landed: transient saved-search scoring ranks the feed and displays concise match explanations without a migration (07-12)
- Ticket 021 landed: scheduled scrape-to-notification lifecycle validated without live provider or notification calls, including repeat-run idempotency (07-12)
- Ticket 022 landed: secure authenticated Pushover user-key settings close the notification configuration UI gap (07-12)
- Ticket 023 landed: grouped per-user run summaries link to persisted, user-isolated match results; live Pushover credentials and delivery validated (07-12)
- Ticket 024 landed: conservative cross-source identity suppresses confirmed syndicated duplicates without fuzzy merging (07-12)
- InfoCasas location follow-up: explicit Villa del Cerro and misspelled Buce0 titles normalize to Cerro/Buceo and override incorrect Centro provider fallbacks (07-12)
- Remax URL follow-up: canonical detail URLs now use the provider's `/listings/:slug` route without an invented trailing ID (07-12)
- Source coverage follow-up: Remax, Housi, and Imperium queries are Montevideo-wide instead of Pocitos-only; missing neighborhoods are no longer mislabeled as Pocitos (07-12)
- Authoritative neighborhoods: IDE Uruguay's 62-feature Montevideo GeoJSON has a reproducible import task and coordinate-based labels override provider metadata (07-12)
- Ticket 025 landed: the runs workbench reports spatial, provider-fallback, unresolved, and provider-versus-polygon mismatch counts (07-12)
- Ticket 026 landed: per-source coordinate coverage is visible; one-page probes validated all four real providers; InfoCasas detail backfill succeeded for 3/3 sampled listings and is scheduled daily with a limit of 20 (07-12)
- Ticket 027 landed: each user can persist English or Spanish; signed-in navigation, feed, searches, runs, notifications, flashes, and score explanations render request-scoped translations (07-12)
- InfoCasas detail follow-up: `commonExpenses` now persists as UYU common expenses and appears on listing cards (07-12)
- Ticket 028A landed: listing-card text tracks align across rows; all signed-in product surfaces show `InfoCasas` without exposing its internal adapter key (07-13)
- Ticket 029 landed: InfoCasas acquisition no longer filters to peso listings; rent symbols normalize to USD/UYU while common expenses remain UYU (07-13)
- Ticket 030 landed: saved searches persist a UYU/USD price currency; bounded feeds and scores never compare unlike currencies, while unbounded feeds remain mixed-currency (07-13)
- Ticket 031 landed: listing cards no longer reserve a fact cell for Type; Source spans the final row while provider type data remains available internally (07-13)
- Ticket 032 landed: the numeric score measures only active saved-search preferences at 70/30 price/bedrooms, disappears for broad searches, and separates listing completeness with higher-contrast styling (07-13)
- Ticket 033 landed: the default feed deduplicates all saved-search matches, active searches can be deselected, cards name matching searches, and bilingual server-side controls sort/filter the dashboard without query-per-search membership execution (07-13)
- Ticket 034 landed: source-local known IDs drive bounded recent pagination for Remax and Imperium; InfoCasas uses hourly publication windows; Housi stays single-page; weekly reconciliation scans deeper without notification fan-out (07-14)
- Ticket 035 landed: Spanish Devise notices and errors cover sign-in, sign-out, registration, password, confirmation, and unlock flows without exposing missing-translation diagnostics (07-14)
- Ticket 036 landed: admin-only inventory operations, user-isolated run history, persisted provider request counts, durable hourly/reconciliation run types, guarded maintenance actions, and structurally verified recurring schedules (07-19)
- Ticket 036 follow-up: scraping runs abandoned for more than two hours are closed automatically instead of blocking maintenance forever (07-19)
- Ticket 036 follow-up: admins can open the current scrape from the dashboard or an overlapping-run warning and watch per-source progress on an auto-refreshing detail page (07-19)
- Ticket 036 follow-up: current-scrape progress now broadcasts over Turbo Streams with cross-process Cable delivery; a slower page refresh remains as a disconnect fallback (07-19)

## Doing
- First-search onboarding implemented locally: branded empty-account welcome, three-step zone/preferences/alerts form, live summary, first-save confirmation and notification setup guidance. Nine integration cases cover actual matching, validation retention and alert readiness; focused suite has 64 tests. Browser QA covered desktop and the final form at 390px; remaining mobile/320px, no-JS and Turbo restoration checks were interrupted by another Chrome extension UI. Full suite: 323 tests, 320 passed; two original baseline failures plus a concurrent public-tour form-count failure outside onboarding. See `docs/superpowers/handoffs/2026-10-23-timbre-onboarding.md`.
- Timbre implementation is ready for release review. Final suite: 327 tests, 2074 assertions, zero failures. The failures recorded in historical branding/navigation/onboarding/tour handoffs are resolved; their detailed visual coverage and remaining onboarding checks remain documented there. Production deployment is pending.
- Portfolio tour and responsive visual redesign implemented locally; 308 Rails tests passed. Browser QA verified sorting, favorite persistence, shortlist navigation, and mobile notification settings. Not deployed.
- Apartment tracking and inline correction follow-up deployed on 10-10. Production QA passed with the dedicated account; public health HTTP 200.

## Blockers
- MercadoLibre public API and HTML probes return access/login gates from this environment; user is obtaining API keys.

## Risks
- Second source introduces currency handling and cross-source dedup risks called out in adapter-contract ADR.
- Real Pushover delivery requires runtime `PUSHOVER_API_TOKEN` and real user `pushover_user_key`; tests use injected fake clients.

## Human Input Needed
- Provide runtime `PUSHOVER_API_TOKEN` before manual end-to-end push validation;
  users can now enter their own Pushover keys in the app.

## Next Step
Resume Ticket 018 when MercadoLibre API keys or an allowed index payload sample are available.
