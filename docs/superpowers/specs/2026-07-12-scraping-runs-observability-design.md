# Scraping Runs Observability Design

## Goal
Make scraper outcomes inspectable from the app without reading Rails logs.

## Scope
Add a signed-in `ScrapingRunsController#index` page at `/scraping_runs`. The page shows recent `ScrapingRun` records with status, started/finished timestamps, listing counts, top-level error text, and each run's `ScrapingSourceRun` rows with source name, status, counts, timing, and error text.

## Design
The page is read-only and uses existing tables only. `ScrapingRun` already stores lifecycle state and aggregate counts; `ScrapingSourceRun` already stores per-source status, counts, and errors. The controller eager-loads `scraping_source_runs` and `listing_source` to avoid N+1 queries.

A small "Runs" link appears in the signed-in header next to the product name so the human can reach the page during development. The UI follows the existing quiet operational style: compact summary rows, status chips, and a per-source nested list.

## Testing
Controller tests cover authentication, rendering recent run summaries, rendering per-source failure details, and avoiding unrelated hidden implementation assumptions. Existing layout tests indirectly protect the stylesheet mirror; any CSS edits must be copied to `public/stylesheets/application.css`.
