# Ticket 036: Inventory-health observability

## Goal
Give administrators enough durable evidence and safe controls to understand and maintain the freshness-first inventory lifecycle.

## Acceptance criteria
- Persist whether each scrape run is hourly acquisition or reconciliation and show it in the admin run history.
- Persist third-party request counts per source run and lifetime source, including coordinate-backfill requests.
- Load and verify hourly, weekly reconciliation, purge, and coordinate-backfill recurring configuration in every environment.
- Let admins safely enqueue acquisition, reconciliation, purge, and coordinate backfill; reject overlapping scrape runs.
- Keep provider controls, inventory location diagnostics, and all maintenance operations inaccessible to non-admin users.
- Cover diagnostics, authorization, request tracking, recurring configuration, and run types with tests.

## Definition of done
- Database migrations are reversible and schema is current.
- English and Spanish labels are present.
- Full test suite and stylesheet mirror check pass.
- Status and roadmap identify Ticket 036 as complete.
