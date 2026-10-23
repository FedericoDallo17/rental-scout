# Timbre branding implementation

The user approved implementing the completed Timbre identity. Implemented locally;
not committed or deployed because the working tree already contains unrelated
in-flight operation-type, scraping, feed/form, schema and README changes.

## Delivered

- Shared brand/head partials for authentication, authenticated navigation and tour.
- Approved, unmodified production SVGs and green/ivory icons, separate maskable
  icon, optical favicon, Apple touch icon, updated install manifest and push icon.
- Locally hosted licensed Manrope Variable, Patio CSS tokens, yellow primary
  actions and green/ivory authentication panel. Both CSS copies stay identical.
- Approved 3300ms D2 door motion adapted to the app: fixed left hinge, 100-degree
  outward projection, lettering through the opening, no fixed frame, original
  final SVG paths. Once per tab; manual replay; no sound; static no-JS/reduced-motion
  fallback; Turbo cache and pagehide cleanup.
- Product-facing Timbre name in English and Spanish. es-UY voice uses Búsquedas,
  Timbres for personal matches, Avisos for settings. Operational admin terminology
  and internal identifiers, routes, sessions, VAPID derivation and notification tags
  remain stable. Notification matching, isolation and deduplication are unchanged.
- Five branded standalone error pages with clear Spanish and English recovery copy.
- Spec, plan, README brand notes and STATUS update.

## Validation

- Before changes: 308 Rails tests, 1834 assertions, two failures.
- Full suite after integration: 310 tests, 1870 assertions, the same two failures.
  No new failures. Targeted verification covers branding metadata, icons,
  authentication, notification settings/results/copy, tour, language and CSS mirror.
- Existing failures left intact:
  - `test/integration/listings_flow_test.rb:169`: expects sidebar metadata `Pocitos`
    but the existing operation-type change renders `Pocitos · Rentals`.
  - `test/jobs/run_scrapers_job_test.rb:247`: queued delivery fixture expects one
    event but receives zero with the existing operation-type/scraping changes.
- Native Chrome QA: local sign in, 24 populated feed cards, desktop and actual
  320/390 CSS-pixel mobile viewports, locally loaded font/images, no horizontal
  overflow, JavaScript errors or failed local requests. Door motion tested at the
  open angle and final original paths, replay, Turbo navigation and reduced motion.
- Extended browser QA passed across 21 captures, including search forms, saved
  page, mobile history and no-JS. Final targeted run: 22 tests, 209 assertions,
  zero failures. Original assets are byte-identical to the kit, and the pre-existing
  backend/schema/search-form diffs were verified unchanged.
  Receipt/screenshots: `/private/tmp/timbre-app-qa/`; driver:
  `/private/tmp/timbre-app-browser-qa.mjs`.
- `git diff --check` passes. No live scrape or notification delivery was triggered.

## Review / next steps

Review locally at `http://127.0.0.1:3127` while the preview server is running.
The brand kit remains published at
`https://timbre-logos-20261022.agilesage5.chatgpt.site`.
Keep the prior operation-type and scraper changes separate when committing.
Resolve the two baseline failures before treating the combined working tree as
release-ready. Production deployment and domain/trademark work are pending.
